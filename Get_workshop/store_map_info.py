# store maps_info to mysql
# By:TunArund
# 2025/1/29
import mysql.connector
import json,os
import get_map_info
from dotenv import load_dotenv
load_dotenv()

def info2file(maps_info,file_name="map_info.txt"):
    """
    maps_info = [info1,info2,...]
    info={
        "link": "https://steamcommunity.com/sharedfiles/filedetails/?id=213123",
        "title": "xxx",
        "size": "500MB",
        "rating_num": "1,592 rating",
        "rating": "5",
        "description": "xxx",
        "img_urls": ["https://asdasd", "https://asdasd"]
    }
    file= json(info1)\njson(info2)\n
    """
    cfp=os.path.abspath(__file__)
    cfp=os.path.dirname(cfp)
    dst_file=os.path.join(cfp,file_name)
    with open(dst_file,'w',encoding='utf-8') as f:
        i=0
        length=len(maps_info)
        for info in maps_info:
            i+=1
            f.write(json.dumps(info,ensure_ascii=False))
            f.write('\n')
            print(f"{i}/{length} 正在写入{info['link']} ")
    print(f"已全部写入文件{dst_file}")

def info2table(maps_info, tolocal):
    """
    maps_info = [info1,info2,...]
    info={
        "link": "https://steamcommunity.com/sharedfiles/filedetails/?id=213123",
        "title": "xxx",
        "size": "500MB",
        "rating_num": "1,592 rating",
        "rating": "5",
        "description": "xxx",
        "img_urls": ["https://asdasd", "https://asdasd"]
    }
    mysql>desc table maps
    Field       | Type         | Null | Key | Default | Extra          |
    +-------------+--------------+------+-----+---------+----------------+
    | id          | int unsigned | NO   | PRI | NULL    | auto_increment |
    | size        | varchar(16)  | YES  |     | NULL    |
    | title       | varchar(256)  | YES  |     | NULL    |
    | link        | varchar(256) | YES  |     | NULL    |
    | description | text         | YES  |     | NULL    |
    | img_urls    | text         | YES  |     | NULL    |
    | rating      | char(1)      | YES  |     | NULL    |
    | rating_num  | varchar(16)  | YES  |     | NULL    |
    """
    # Initialize MySQL parameters
    table = 'maps'
    remo_para = {
        'host': os.getenv("SERVER_ADDR"),
        'user': os.getenv("DB_USER"),
        'password': os.getenv("DB_PASS"),
        'database': os.getenv("DB_NAME")
    }
    local_para ={
        'host': "localhost",
        'user': "workshop",
        'password': "wolaizuchengtoubu",
        'database': "trashcan"
    }
    if tolocal:
        conn_para = local_para
    else:
        conn_para = remo_para
    db = mysql.connector.connect(**conn_para)
    print(f"mysql数据库连接成功：{conn_para}")
    cursor = db.cursor()
    sql_insert = "INSERT INTO {} (size, title, link, description, img_urls, rating, rating_num) VALUES (%s, %s, %s, %s, %s, %s, %s)".format(table)
    sql_select = "SELECT COUNT(*) FROM maps WHERE link = %s"
    # Loop select insert
    i=0
    length=len(maps_info)
    for info in maps_info:
        i+=1
        cursor.execute(sql_select, (info['link'],))# link is unique(because item's steamid)
        result = cursor.fetchone()
        if result[0] > 0:
            print(f"{i}/{length}：{info['title']}已存在")
            continue
        print(f"正在插入{i}/{length}：{info['title']}")
        cursor.execute(sql_insert, 
            (
                info['size'],
                info['title'],
                info['link'],
                info['description'],
                json.dumps(info['img_urls']),
                info['rating'],
                info['rating_num']
            )
        )    
    cursor.close()
    db.commit()
    db.close()

def store_map_info(tolocal=False):
    maps_info = get_map_info.get_maps_info()
    info2table(maps_info, tolocal)
    #info2file(maps_info)

if __name__ == '__main__':
    store_map_info()
