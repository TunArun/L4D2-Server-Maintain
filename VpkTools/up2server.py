import time
import paramiko
import os
from dotenv import load_dotenv
load_dotenv()

# 自定义进度回调函数
def progress_callback(transferred, total):
    progress = transferred / total * 100
    remaining = (total - transferred) / (transferred / (time.time() - start_time)) if transferred > 0 else 0
    print(f"\r{transferred}/{total} bytes transferred ({progress:.2f}%) | "
          f"Remaining time: {remaining:.2f}s | Speed: {transferred / (time.time() - start_time) / 1024:.2f} KB/s", end='')

def connect():
    # 创建一个SSH客户端
    ssh = paramiko.SSHClient()
    # 自动添加主机密钥
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    # 连接到SSH服务器
    ssh.connect(os.getenv('SERVER_ADDR'), username=os.getenv('ADMIN'), password=os.getenv('ADMIN_PASS'))
    # 创建一个SFTP客户端
    return ssh


start_time = None

if __name__ == '__main__':
    ssh = connect()
    sftp = ssh.open_sftp()
    # 上传文件
    cfp = os.path.dirname(__file__)
    local_path = os.path.join(cfp, "dist", "vpktools.exe")
    remote_path = '/var/www/html/static/eta/vpktools.exe'
    # 记录上传开始时间
    start_time = time.time()
    sftp.put(local_path, remote_path, callback=progress_callback)
    # 关闭SFTP客户端和SSH连接
    sftp.close()
    ssh.close()