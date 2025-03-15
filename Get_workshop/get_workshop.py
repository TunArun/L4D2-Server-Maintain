# ssh
from time import sleep, time
import paramiko,os
from dotenv import load_dotenv
load_dotenv()

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
        print("Connection failed:", e)
        return e
    shell = ssh.invoke_shell()
    print("Connected to the server")
    # sftp会话与shell是独立的，所以要给出完整路径+文件名
    sftp = ssh.open_sftp()
    sftp.put(local_filename, remote_path+remote_filename)
    sftp.close()
    # tmux
    shell.send('tmux attach -t cmd1\n')
    shell.send('\b\b./downmap.sh\n')
    ssh.close()

# 链接解析
import requests,json,re
# 获取src文件中的id
def get_src_data(src):
    pattern = r'id=(\d+)'
    datas = []
    with open(src, 'r') as f:
        for line in f:#按行读取
            # 截取id
            match = re.search(pattern, line)
            if match:
                id = match.group(1)
                datas.append('['+id+']')
    return datas

# 根据id获取文件名和下载链接files
def get_target_site(datas):
    headers = {

        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36 Edg/130.0.0.0',
        'Origin' : 'https://steamworkshopdownloader.io',
        'Rerferer': "https://steamworkshopdownloader.io/"
    }
    files = []
    i=0
    for data in datas:
        # request请求
        with requests.post('https://steamworkshopdownloader.io/api/details/file', headers=headers, data=data) as response:
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
        print(f'success {i}/{len(datas)} {file_name}')
        sleep(0.1)
    return files
# 把files(filename url)保存到path文件
def save_file(files,path):
    with open(path, 'w') as f:
        for file in files:
            f.write(file + '\n')
            f.flush()

# store_map_info
import store_map_info

if __name__ == '__main__':
    src = 'src_url.txt'
    local_filename = 'urls.txt'
    remote_path = os.getenv('ADDON_PATH')
    remote_filename = 'urls.txt'
    while True:
        print('菜单')
        print('0 退出')
        print('1 开始转换')
        print('2 ssh')
        print('3 存储地图信息到服务器')
        choice = input('请输入选项：')
        if choice == '0':
            break
        elif choice == '1':
            datas = get_src_data(src)
            files = get_target_site(datas)
            save_file(files,local_filename)
        elif choice == '2': 
            Shell(local_filename, remote_path, remote_filename)
        elif choice == '3':
            print('开始存储地图信息')
            store_map_info.store_map_info()
        else:
            print('无效选项，请重新输入。')
        

