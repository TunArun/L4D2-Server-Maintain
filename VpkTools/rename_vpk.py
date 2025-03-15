# Rename vpk by its workshop id or inner addoninfo
# by:TunArund 2025/3/11
import os,sys
from lxml import html
import requests,time
import vpk
import json
from pathvalidate import sanitize_filename
cfp = None
log_file = None

# specific cfp by python script or executable
def get_cfp():
    if __file__:
        return os.path.dirname(os.path.abspath(__file__))
    elif sys.executable:
        return os.path.dirname(os.path.abspath(sys.executable)) 
# open utf-8 log file 
def open_log_file(cfp):
    log_path = os.path.join(cfp, 'rename_vpk.log')
    file = None
    if os.path.exists(log_path):
        file = open(log_path, 'a', encoding='utf-8')
    else:
        return open(log_path, 'w', encoding='utf-8')
    file.write('\n')
    return file
def read_json_file(cfp):
    json_path = os.path.join(cfp, 'rename_vpk.json')
    if os.path.exists(json_path):
        try:
            with open(json_path, 'r') as f:
                return json.load(f)
        except:
            return {}
    return {}

def ensure_utf8(data):
    if isinstance(data, dict):
        return {ensure_utf8(key): ensure_utf8(value) for key, value in data.items()}
    elif isinstance(data, list):
        return [ensure_utf8(item) for item in data]
    elif isinstance(data, str):
        return data.encode('utf-8', errors='ignore').decode('utf-8')
    else:
        return data
def write_json_file(cfp, name_kv):
    with open(os.path.join(cfp, 'rename_vpk.json'), 'w', encoding='utf-8') as f:
        name_kv = ensure_utf8(name_kv)
        json.dump(name_kv, f, indent=4, ensure_ascii=False)

# get vpk file names
def get_file_names(cfp):
    """
    check current path and addons path
    """
    # ls current file path
    files = os.listdir(cfp)
    # addon path
    addon_path = os.path.join(cfp, 'addons')
    if os.path.isdir(addon_path):
        files += os.listdir(addon_path)
    # filter vpk from files
    vpk_files = []
    for file in files:
        if file.endswith('.vpk'):
            path = os.path.join(cfp, file)
            vpk_files.append(path)
    return vpk_files
    
# get name by workshop id
def get_name_by_id(name,max_retry=3):
    """
    reutrn{
        "link": "https://steamcommunity.com/sharedfiles/filedetails/?id=3254590445",
        "name": "xxx",
    }
    """
    # build link
    result = {}
    url = f"https://steamcommunity.com/sharedfiles/filedetails/?id={name}"
    result['link'] = url
    # get html
    headers={
        "user-agent" : "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36 Edg/131.0.0.0"
    }
    # Insist Request until max_retry
    i = 0 
    while i < max_retry:
        i += 1
        try:
            response = requests.get(url, verify=False, headers=headers)
            break
        except requests.exceptions.ConnectionError:
            # 如果请求失败，打印错误信息
            print(f"{name}第{i}次请求失败")
            time.sleep(0.5)
    if not response:
        print(f"{name}请求失败,检查网络连接和get_name_by_id函数")
        return None
    # text->lxml.html
    res_txt = response.text
    res_html =  html.fromstring(res_txt)
    # 名称xpath
    title_xpath = "//*[@id=\"mainContents\"]/div[3]/div[2]"
    result['name'] = res_html.xpath(title_xpath)[0].text
    return result

# get name by inner addoninfo
def get_name_by_addoninfo(name):
    try:
        pak = vpk.VPK(name)
    except Exception as e:
        print_log(f'{name} 打开失败,不是合法vpk文件？{e}')
        return None
    addoninfo_file = pak['addoninfo.txt']
    addoninfo_string = addoninfo_file.read().decode()
    # filter out title
    candidates = ['addonTitle', 'AddonTitle', 'addontitle', 'Addontitle']
    title_pos = -1
    for candi in candidates:
        title_pos = addoninfo_string.find(candi)
        if title_pos != -1:
            break
    if title_pos == -1:
        print_log(f'没有在{name}/addoninfo.txt找到addonTitle')
    # 下方方式有bug，有的addoninfo.txt没有双引号
    # title_pos=  addonTitle" "xxxxx"
    title_pos = addoninfo_string.find('"', title_pos+1)
    title_pos = addoninfo_string.find('"', title_pos+1)
    # title_pos=  "xxxxx"
    title_pos_end =  addoninfo_string.find('"', title_pos+1)
    return addoninfo_string[title_pos+1:title_pos_end]

# choose
def choose(name):
    if name.isdigit():
        return 'pure number'
    return 'not pure number'
    

def log(text):
    try:
        timestamp = time.strftime('%Y-%m-%d %H:%M:%S',time.localtime(time.time()))
        log_file.write(timestamp+' '+text+ '\n')
        log_file.flush()
    except Exception as e:
        print(f'{text} 写入日志失败 {e}')
        return False
    return True
def print_log(text):
    print(text)
    log(text)
# log and rename vpk(jpg/png)
def log_and_rename(src_name, dst_name):
    """
    src_name=/path/to/file.vpk
    dst_name=/path/to/dst.vpk
    """
    print_log(f'{src_name} -> {dst_name}')
    try:
        os.rename(src_name, dst_name)
    except Exception as e:
        print_log(f'重命名失败{e}\n{src_name} -> {dst_name}')
        return False
    
    src_img = src_name.replace('.vpk', '.jpg')
    dst_img = dst_name.replace('.vpk', '.jpg')
    if os.path.isfile(src_img):
        try:
            os.rename(src_img, dst_name.replace('.vpk', '.jpg'))
        except Exception as e:
            print_log(f'重命名失败{e}\n{src_img} -> {dst_img}')
    return True


if __name__ == '__main__':
    # Initialize cfp/log/vpk
    cfp = get_cfp()
    log_file = open_log_file(cfp)
    vpk_files = get_file_names(cfp)
    name_kv = read_json_file(cfp) # store validated src_name and dst_name without extension or parent_path
    # walk files and rename
    for file in vpk_files:
        file_noext = os.path.basename(file).split('.')[0]
        choice = choose(file_noext)
        if choice == 'pure number':
            result = get_name_by_id(file_noext)
            name = result['name']
            print_log(f"{result['link']} -> {name}")
        elif choice == 'not pure number':
            name = get_name_by_addoninfo(file)
        else:
            print_log(f'choose函数返回值错误 {choice}')
            continue
        if name is None:
            print_log(f'{file} 没有通过addoninfo找到名字')
            continue
        name = sanitize_filename(name, replacement_text='_') # 替换非法字符
        name = os.path.join(cfp, name+'.vpk')
        if log_and_rename(file, name):
            src_name = os.path.basename(file)
            dst_name = os.path.basename(name)
            name_kv[src_name] = dst_name
    write_json_file(cfp, name_kv)
    log_file.close()
    
        