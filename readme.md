[TOC]

# TunArund L4D2 Server Maintaince

## 简介
这个仓库用于记录L4D2服务器维护过程中遇到的问题和解决方案，方便以后查阅。
使用了gitignore的[白名单模式](https://cn.linux-console.net/?p=7733)

## Mail
已安装postfix dovecot，未配置

## 服务器配置
!!!本机mstsc端口改注册表改成15837了

SteamCMD下载创意工坊 https://blog.csdn.net/llfdhr/article/details/132222752
网页下载创意工坊 https://steamworkshopdownloader.io/
插件、vpk D:/yincang/Games/求生之路2
录像 E:\LenovoSoftstore\Movie\Left 4 Dead 2
创建药役、尸潮模式ing

多特控制考虑转交NekoSpecial，可能导致崩溃
还有csm选择角色也可能导致崩溃
安全屋传送
随机初始地图
尸潮改为cvar模式
z_common_limit                          80
z_mob_spawn_finale_size                  80
z_mob_spawn_max_size                     60
z_mob_spawn_min_size                     40

z_mob_spawn_max_interval_easy            50
z_mob_spawn_max_interval_normal          45
z_mob_spawn_max_interval_hard            40
z_mob_spawn_max_interval_expert          40
        
z_mob_spawn_min_interval_easy            45
z_mob_spawn_min_interval_normal          40
z_mob_spawn_min_interval_hard            35
z_mob_spawn_min_interval_expert          35

z_mega_mob_size                          80
z_mega_mob_spawn_max_interval            42
z_mega_mob_spawn_min_interval            36
z_wandering_density 		         0.1
z_speed 250
z_health 45
z_background_limit 100

药役增加医疗物资
无法卸载模式

武器数据修改.vpk
将大狙和鸟狙伤害改为300，手枪伤害改为134，减少扩散并加强了穿透

## 脚本
### Get_workshop
get_workshop.py通过[steamworkshopdownloader.io](https://steamworkshopdownloader.io/)将src_url.txt中的订阅链接转换为：“名称 文件URL”并写入urls.txt
get_map_info.py通过订阅链接获取地图封面、名称、大小等信息，返回json格式
store_map_info.py将get_map_info.py获取的json格式信息存入数据库
rename_vpk.py扫描其所处目录下的addons目录，获取vpk文件名，对于纯数字文件名，通过构造订阅链接获取名称，否则通过vpk解包addoninfo.txt-addonTitle获取名称，并修改原文件名，记录到rename_vpk.log
## docker备份
重要目录
/home/steam/l4d2server/left4dead2
/var/html/www
数据库
mysql-steam

python scricpts
certbot
