[TOC]

# TunArund L4D2 Server Maintaince

## 简介
这个仓库用于记录L4D2服务器维护过程中遇到的问题和解决方案，方便以后查阅。
使用了gitignore的[白名单模式](https://cn.linux-console.net/?p=7733)
服务器地址l4d2.tunarund.top
求生小队Q群：[646920616](https://qm.qq.com/q/7eV7e1XlOo)
![二维码](https://l4d2.tunarund.top/static/img/小队Q群.jpg)

每晚9点打三方图，尸潮多特，欢迎大家来~~坐牢~~玩啊

## 备忘录
- sourcemod插件平台指令https://wiki.alliedmods.net/Managing_your_Sourcemod_installation/zh
- sourcemod/plugins目录下，optional和disabled目录下的文件不会被加载，其他都可以加载
- tmux终端复用https://www.linuxmi.com/linux-tmux.html
- confoglc插件管理
!!!本机mstsc端口改注册表改成15837了
- 创意工坊下载
SteamCMD https://blog.csdn.net/llfdhr/article/details/132222752
网页 https://steamworkshopdownloader.io/
- 创建药役、尸潮模式、对抗模式
- 武器数据修改.vpk
将大狙和鸟狙伤害改为300，马格南减少扩散并加强了穿透
- 多特控制插件目前是AI_HardSI.smx特感0帧起手实在难绷
考虑转交新的特感控制插件NekoSpecial~~可能导致崩溃,还有csm选择角色插件也可能导致崩溃~~
- 考虑增加安全屋超时传送、玩门处死插件

- CutlrBtree Overflow溢出？参见fdxx大佬的[仓库](https://github.com/fdxx/cutlrbtreefix)
## Todo
- [ ] 将服务器的cfg和sourcemod同步到仓库
- [ ] 添加地图上传功能，限制上传次数
- [ ] gamemaps解析
- [x] 随机初始地图（但是只有才服务器进程重启时切换）
- [ ] 尸潮改为cvar模式
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

## 脚本
### Get_workshop
1. get_workshop.py
通过[steamworkshopdownloader.io](https://steamworkshopdownloader.io/)将src_url.txt中的订阅链接转换为：“名称 文件URL”并写入urls.txt
2. get_map_info.py
通过订阅链接获取地图封面、名称、大小等信息，返回json格式
3. store_map_info.py
将get_map_info.py获取的json格式信息存入数据库
4. rename_vpk.py
扫描其所处目录下的addons目录，获取vpk文件名
对于纯数字文件名：通过构造订阅链接获取名称
对于非纯文字文件：通过vpk解包addoninfo.txt-addonTitle获取名称
修改文件名
详细操作和报错记录到rename_vpk.log
"新文件名":"旧文件名"存入rename_vpk.json
### Vpktools
某人不会将vpk文件移到addons目录下，于是调用tkinter写了个图形程序，自动检测steam目录然后寻找Left 4 Dead 2将vpk文件移到addons目录下
## docker备份
重要目录
/home/steam/l4d2server/left4dead2
/var/html/www
数据库
mysql-steam
脚本
/home/steam/l4d2/scripts
网站
certbot
