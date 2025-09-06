import os
import requests
from urllib.parse import urlparse

def download_file(url, file_path=None, resume=True, chunk_size=1024, headers=None):
    """
    下载文件，支持断点续传和非断点续传
    参数:
        url (str): 要下载的文件URL
        file_path (str): 本地保存路径，如果为None则自动从URL提取文件名
        resume (bool): 是否启用断点续传
        chunk_size (int): 每次下载的块大小(字节)
        headers (dict): 自定义请求头
    返回:
        bool,str: 成功与否，下载完成的文件路径
    """
    # 设置默认请求头
    if headers is None:
        headers = {}
    # 如果没有指定保存路径，则从URL中提取文件名
    if file_path is None:
        file_path = os.path.basename(urlparse(url).path) or "downloaded_file"
    # 确保目录存在
    os.makedirs(os.path.dirname(file_path) or ".", exist_ok=True)
    # 获取文件大小和已下载大小
    file_size = 0
    downloaded_size = 0
    mode = 'wb'  # 默认写入模式
    if resume and os.path.exists(file_path):
        downloaded_size = os.path.getsize(file_path)
        if downloaded_size > 0:
            # 添加Range头实现断点续传
            headers['Range'] = f'bytes={downloaded_size}-'
            mode = 'ab'  # 追加模式 
    try:
        with requests.get(url, stream=True, headers=headers) as response:
            response.raise_for_status()    
            # 检查服务器是否支持断点续传
            if resume and downloaded_size > 0:
                if response.status_code != 206:  # 206表示部分内容
                    print("服务器不支持断点续传，将重新下载")
                    downloaded_size = 0
                    mode = 'wb'
            # 获取总文件大小
            file_size = int(response.headers.get('content-length', 0)) + downloaded_size
            # 显示下载信息
            print(f"下载文件: {url}")
            print(f"保存到: {file_path}")
            print(f"文件大小: {file_size / (1024 * 1024):.2f} MB")
            if downloaded_size > 0:
                print(f"已下载: {downloaded_size / (1024 * 1024):.2f} MB")
                print(f"剩余: {(file_size - downloaded_size) / (1024 * 1024):.2f} MB")
            # 开始下载
            with open(file_path, mode) as f:
                for chunk in response.iter_content(chunk_size=chunk_size):
                    if chunk:  # 过滤掉保持连接的新块
                        f.write(chunk)
                        downloaded_size += len(chunk)
                        # 显示进度
                        if file_size > 0:
                            percent = (downloaded_size / file_size) * 100
                            print(f"进度: {percent:.2f}% ({downloaded_size / (1024 * 1024):.2f}/{file_size / (1024 * 1024):.2f} MB)", end='\r')
            print("\n下载完成!")
            return True,file_path
    except requests.exceptions.RequestException as e:
        print(f"下载失败: {e}")
        return False,e
    # except KeyboardInterrupt:
    #     print("\n下载被中断")
    #     if os.path.exists(file_path) and os.path.getsize(file_path) == 0:
    #         os.remove(file_path)
        return False,"下载被中断"
    except Exception as e:
        print(f"发生错误: {e}")
        if os.path.exists(file_path) and os.path.getsize(file_path) == 0:
            os.remove(file_path)
        return False,e
# 使用示例
if __name__ == "__main__":
    # 测试URL（可以替换为任何大文件URL进行测试）
    test_url = "https://www.python.org/ftp/python/3.9.7/python-3.9.7-amd64.exe"
    print("=== 断点续传模式 ===")
    download_file(test_url, "python_installer.exe", resume=True)
    print("\n=== 非断点续传模式 ===")
    download_file(test_url, "python_installer_new.exe", resume=False)