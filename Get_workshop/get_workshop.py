# ssh
from time import sleep, time
import paramiko,os
from dotenv import load_dotenv
load_dotenv()
import logger
logger = logger.file_cmd_logger('get_workshop.log')
def wait_for_command(shell, timeout=10):
    """
    动态等待命令执行完成，直到捕获提示符或超时。
    """
    end_time = time() + timeout
    output = ""
    while time() < end_time:
        if shell.recv_ready():
            output += shell.recv(65535).decode()
            if output.strip().endswith(("$", "#")):  # 根据提示符判断命令完成
                break
        sleep(0.1)
    return output

def Shell(local_filename, remote_path, remote_filename):
    # 连接
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    try:
        ssh.connect(os.getenv('SERVER_ADDR'), username=os.getenv('SERVER_GUEST'), password=os.getenv('GUEST_PASS'))
    except Exception as e:
        logger.info(f"Connection failed:{e}")
        return e
    shell = ssh.invoke_shell()
    logger.info("Connected to the server")
    # sftp会话与shell是独立的，所以要给出完整路径+文件名
    sftp = ssh.open_sftp()
    sftp.put(local_filename, remote_path+remote_filename)
    sftp.close()
    # tmux
    # shell.send('tmux attach -t cmd1\n')
    # shell.send('\b\b./downmap.sh\n')
    ssh.close()

# 链接解析
import requests,json,re
# 获取src文件中的id
def get_src_data(src):
    pattern = r'id=(\d+)'
    datas = []
    with open(src, 'r', encoding='utf-8') as f:
        for line in f:#按行读取
            # 截取id
            match = re.search(pattern, line)
            if match:
                id = match.group(1)
                datas.append('['+id+']')
    return datas

# 根据id获取文件名和下载链接files
def get_target_site(datas, proxies=None):
    """
    return ['name url',]
    """
    headers = {

        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36 Edg/130.0.0.0',
        'Origin' : 'https://steamworkshopdownloader.io',
        'Rerferer': "https://steamworkshopdownloader.io/"
    }
    files = []
    i=0
    for data in datas:
        # request请求
        with requests.post('https://steamworkshopdownloader.io/api/details/file', headers=headers, data=data, proxies=proxies) as response:
            if not response.status_code == 200:
                continue
        i+=1
        text = response.text
        json_data = json.loads(text)
        file_url = json_data[0]['file_url']
        # 文件名处理
        file_name = json_data[0]['title_disk_safe']+'.vpk'
        # 保存文件名和下载链接
        files.append(file_name + ' ' + file_url)
        logger.info(f'success {i}/{len(datas)} {file_name}')
        
    return files
# 把files：filename url，写入path文件
def save_file(files,path):
    with open(path, 'w') as f:
        for file in files:
            f.write(file + '\n')
            f.flush()

import download
def download_files(dir,files,retry=5):
    """
    files = ['name url','name url done',]
    return error_file=['name url',]
    """
    remain = len(files)
    error_file = []
    while remain > 0 and retry > 0:
        #遍历一次
        for file in files:
            parts = file.split()
            name = parts[0]
            url = parts[1]
            done = parts[2] if len(parts) > 2 else None
            if done == 'done':
                remain-=1
                logger.info(f"Skipping {name} as it's already downloaded.")
                continue
            result,reason = download.download_file(url, os.path.join(dir, name),
                                                    resume=True, chunk_size=1024)
            if result==True:
                remain-=1
            else:
                logger.error(f"downloading {name}: {reason}")
                error_file.append(file)
        retry-=1
    # 全部下载成功或重试次数用完
    if remain > 0:# 重试次数用完
        logger.error(f"Failed to download {remain} files after {retry} retries.")
        for file in error_file:
            logger.info(f"Error file: {file}")
    else: # 全部下载成功
        logger.info("All files downloaded successfully.")
    return error_file
# 交互模式
def interactive_mode(src, directory, local_filename, remote_path, remote_filename):
    """
    src: src_url.txt steamshraelinks
    dir: ./ download vpk to
    local_filename: urls.txt
    remote_path: /home/guest/steam/
    remote_filename: urls.txt
    """
    while True:
        print('菜单')
        print('0 退出')
        print('1 解析src链接url')
        print('2 ssh')
        print('3 存储地图信息到服务器')
        print('4 开始下载')
        choice = input('请输入选项：')
        if choice == '0':
            return 0
        elif choice == '1':
            datas = get_src_data(src)
            proxies = None
            use_proxy = input('是否使用.env中的代理？（Y/N）')
            if use_proxy == 'Y':
                proxies = {
                    'http': os.getenv('HTTP_PROXY'),
                    'https': os.getenv('HTTPS_PROXY')
                }
            files = get_target_site(datas, proxies)
            save_file(files,local_filename)
        elif choice == '2': 
            Shell(local_filename, remote_path, remote_filename)
        elif choice == '3':
            logger.info('开始存储地图信息')
            store_map_info.store_map_info()
        elif choice == '4':
            with open(local_filename, 'r') as f:
                files = f.readlines()
                if not files:
                    print('文件为空，请先解析src链接url。')
                error_file = download_files(directory,files)          
        else:
            print('无效选项，请重新输入。')
def parameter_mode():
    pass
# store_map_info
import store_map_info
import sys
if __name__ == '__main__':
    # 准备变量
    cfp = os.path.dirname(os.path.abspath(__file__))
    src = os.path.join(cfp, 'src_url.txt')
    local_filename = os.path.join(cfp,'urls.txt')
    remote_path = os.getenv('ADDON_PATH')
    remote_filename = 'urls.txt'
    #获取参数
    args = sys.argv
    if len(args) == 1:
        directory = os.path.join(cfp,'download')
        interactive_mode(src, directory, local_filename, remote_path, remote_filename)
    else:
        datas = get_src_data(src)
        

