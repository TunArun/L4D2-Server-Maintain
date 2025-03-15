# extract addoninfo.txt from vpk
# by: TunArund
# 2025/1/18
import vpk
import os


def save_info(vpk_instance, path):
    try:
        info_file = vpk_instance.get_file("addoninfo.txt")
    except:
        return False
    name = os.path.basename(vpk_instance.vpk_path)
    name = name.replace(".vpk",".txt")
    file_name = os.path.join(path,name)
    if not os.path.exists(file_name):
        info_file.save(file_name)
    return True


if __name__ == "__main__":
    # 准备路径
    cfp = os.path.abspath(__file__) # 获取当前文件路径
    cfd = os.path.dirname(cfp) # 获取当前文件所在目录
    addon_path = r"E:\Program Files (x86)\Steam\steamapps\common\Left 4 Dead 2\left4dead2\addons" # vpk文件路径
    vpk_files = os.listdir(addon_path) 
    vpk_files = [f for f in vpk_files if f.endswith(".vpk")] # 筛选出vpk文件
    info_path = os.path.join(cfd,"addoninfo") # /path/to/cwd/addoninfo保存路径
    if not os.path.exists(info_path):
        os.mkdir(info_path)
    print(f"在{addon_path}找到\n{len(vpk_files)}个vpk")
    # sys.exit(0)
    i=0 # 成功计数
    failed=[] # 失败记名
    for file in vpk_files:
        vpk_instance = vpk.open(os.path.join(addon_path, file))
        result = save_info(vpk_instance,info_path)
        if result == True:
            i+=1
        else:
            failed.append(file)
    for f in failed:
        print(f)
    print(f"成功保存{i}个addoninfo.txt, 失败文件名如上")

    
