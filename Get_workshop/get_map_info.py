# spider maps_info from steam_workshop
# By:TunArund
# 2025/1/15
import json
import os
import sys
from lxml import html
import requests
import re


def file2url(src):
    """
    src="path/to/id.txt" utf-8
    return ['https://steamcommunity.com?id=213123',...]
    """
    result = []
    id_pattern = r"id=(\d+)"# id counts but not for search_text
    with open(src, "r") as f:
        for line in f:
            try:# filter lines without 'id=xxxxxxx'
                id = re.search(id_pattern, line).group(1)
                if id:
                    result.append("https://steamcommunity.com/sharedfiles/filedetails/?id="+id)
            except:
                continue
    return result

def url2html(url,save=False):
    """
    save: 是否保存为url.html
    return lxml.html
    """
    headers={
        "user-agent" : "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36 Edg/131.0.0.0"
    }
    # 请求
    try:
        response = requests.get(url, verify=False, headers=headers)
    except requests.exceptions.ConnectionError:
        # 如果请求失败，打印错误信息
        print(f"{url}请求失败")
        sys.exit(1)
    if save:# 暂存html
        with open(f"{url}.html", "w", encoding="utf-8") as f:
            f.write(response.text)
    # text->lxml.html
    res_txt = response.text
    return html.fromstring(res_txt)

# 从script标签中提取url
def txt2imgurl(img_script):
    """
    img_script: 包含 rgScreenshotURLs 数据的脚本标签内容
    var rgFullScreenshotURLs = [
        {'previewid':'772398', 'url':'https://steamuserimages-a.akamaihd.net/ugc/'},
        {},
    ]
    return False
    return ['https://asdasd', 'https://asdasd']
    """
    # 确保提取成功
    if not img_script:
        print("Script containing rgScreenshotURLs not found.")
        return False
    script_text = img_script[0]
    # 提取 rgScreenshotURLs 数据
    full_screenshot_match = re.search(r"var rgFullScreenshotURLs = (\[.*?\]);", script_text, re.DOTALL)
    # 确保匹配到了数据
    if not full_screenshot_match:
        print("Failed to extract rgScreenshotURLs or rgFullScreenshotURLs.")
        return False
    full_screenshot_data = full_screenshot_match.group(1)
    fixed_json = full_screenshot_data.replace("'", '"') # 替换单引号为双引号
    fixed_json = re.sub(r",\s*([}\]])", r"\1", fixed_json) # 删除多余(末尾)的逗号
    # 解析为 Python 对象
    full_screenshots = json.loads(fixed_json)
    # 提取所有的 URL
    urls = [item["url"] for item in full_screenshots]
    return urls
def html2info(url,res_html):
    """
    reutrn{
        "link": "https://steamcommunity.com/sharedfiles/filedetails/?id=213123",
        "title": "xxx",
        "size": "500MB",
        "rating_num": "1,592 rating",
        "rating": "5",
        "description": "xxx",
        "img_urls": ["https://asdasd", "https://asdasd"]
    }
    """
    result = {}
    # 各种xpath
    title_xpath = "//*[@id=\"mainContents\"]/div[3]/div[2]"
    size_xpath = [ # 在这里添加新的文件大小xpath
        '//*[@id="mainContents"]/div[8]/div/div[2]/div[4]/div[2]/div[1]',
        '//*[@id="mainContents"]/div[8]/div/div[2]/div[3]/div[2]/div[1]' #老版文件大小xpath，如2014年的Train Yard
    ]
    rating_num_xpath = "//*[@id=\"detailsHeaderRight\"]/div/div[2]"
    rating_xpath = '//*[@id="detailsHeaderRight"]/div/div[1]/img/@src'
    description_xpath = '//div[@id="highlightContent"]'
    img_xpath = [
        '//*[@id="highlight_player_area"]/script/text()',
        '//*[@id="previewImage"]/@src' # 老版预览图xpath，如2014年的Train Yard
    ]
    # 根据xpath取值
    result['link'] = url
    result['title'] = res_html.xpath(title_xpath)[0].text
    for xpath in size_xpath:
        try:
            result['size'] = res_html.xpath(xpath)[0].text
            break
        except:
            pass
    if 'size' not in result:
        result['size'] = "未知"
        print(f"未找到文件大小，请检查网页中的文件大小xpath并添加html2info/size_xpath,url={url}")
    result['rating_num'] = res_html.xpath(rating_num_xpath)[0].text
    # rating
    rating = res_html.xpath(rating_xpath)[0]
    result['rating'] = rating.split("/")[-1].split("-")[0] 
    # description
    description = res_html.xpath(description_xpath)
    result['description'] = html.tostring(description[0]).decode()
    # img_urls
    img_script = res_html.xpath(img_xpath[0]) # 多个标签
    img_urls = txt2imgurl(img_script) # 用函数取
    if len(img_urls) == 0 or img_urls == False:# 没取到
        print(f"未找到预览图，url={url}")
        found = False
        for xpath in img_xpath[1:]:
            print(f"尝试通过{xpath}寻找")
            img_urls = res_html.xpath(xpath)
            if len(img_urls) != 0:
                found = True
                print(f"找到预览图url，url={url}")
                break
        if not found:
            img_urls = f'未找到预览图url，请检查{url}中的预览图xpath并添加到get_map_info.py/html2info/img_xpath'
            print(img_urls)
    # 最终判断img_urls，只可能是列表或字符串
    if isinstance(img_urls, list):
        pass
    elif isinstance(img_urls, str):# 如果变量是字符串，则将其转换为对应的列表
        img_urls = list(img_urls)
    else:# 处理其他类型的变量
        img_urls = f"不理解的img_urls类型:{img_urls},请检查get_map_info.py/html2info/img"
        img_urls = list(img_urls)
        print(img_urls)
    result['img_urls'] = img_urls
    return result

def get_maps_info(src_file="src_url.txt"):
    # prepare paths
    cfp=os.path.abspath(__file__)
    cfp=os.path.dirname(cfp)
    src_file=os.path.join(cfp,"src_url.txt")
    if not os.path.exists(src_file):
        print(f"{src_file}不存在")
        exit()
    # reade src_file for urls
    urls = file2url(src_file)
    length = len(urls)
    print(f"从{src_file}中读取了{length}个url")
    # loop urls append in maps_info
    maps_info = []
    i=0
    for url in urls:
        i+=1
        res_html = url2html(url)
        info = html2info(url,res_html)
        maps_info.append(info)
        print(f"正在获取第{i}个地图信息，{url}，{info['title']}")
    return maps_info
    
