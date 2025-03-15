import shutil
import subprocess
import os
import sys
import threading
import time
import win32event
import win32api
import winreg
import tkinter as tk
from tkinter import ttk
from tkinter import filedialog



class VPKTools:
    def __init__(self):
        if getattr(sys, 'frozen', False):
            self.cfp = os.path.dirname(sys.argv[0])
        else:
            self.cfp = os.path.dirname(os.path.abspath(__file__))
        self.logfile = self.init_log()
        self.log("程序启动\n")
        self.steam_dir = self.auto_detect_steam()
        self.vpk_dir = self.check_vpk_dir(self.cfp)
        self.setup_window()
        self.update()

    # 创建主窗口
    def setup_window(self):
        # 窗体
        self.main_window = tk.Tk()
        self.main_window.title("VPK Tools 傻瓜版 by:TunArund")
        self.main_window.geometry("550x210")
        self.main_window.protocol("WM_DELETE_WINDOW", self.on_closing)
        style = ttk.Style()
        style.configure("TButton", font=("Arial", 16), padding=10, relief="flat")
        style.configure("TLabel", font=("Arial", 18), padding=10, relief="flat")
        # 文本显示
        self.logtext = tk.StringVar(self.main_window, value="欢迎使用VPK Tools")
        self.loglabel = ttk.Label(self.main_window, textvariable=self.logtext)
        self.loglabel.pack()
        # 进度文本
        self.progress_text = tk.StringVar(self.main_window, value="预估时间: 0s")
        self.progress_label = ttk.Label(self.main_window, textvariable=self.progress_text)
        self.progress_label.pack_forget()
        # 按钮
        self.select_game_dir_btn = ttk.Button(self.main_window, text="手动选择Left 4 Dead 2目录", command=self.select_game_dir)
        self.select_game_dir_btn.pack_forget()

        self.select_vpk_dir_btn = ttk.Button(self.main_window, text="手动选择vpk目录", command=self.select_vpk_dir)
        self.select_vpk_dir_btn.pack_forget()

        self.launch_game_btn = ttk.Button(self.main_window, text="复制vpk并启动游戏", command=self.launch_game)
        self.launch_game_btn.pack_forget()

        self.copy_vpk_btn = ttk.Button(self.main_window, text="仅复制vpk", command=self.copy_vpk)
        self.copy_vpk_btn.pack_forget()

    def on_closing(self):
        self.logfile.close()
        self.main_window.destroy()

    def show(self, text):
        self.logtext.set(text)
    def init_log(self):
        i=1
        log_name = f"vpktools{i}.log"
        log_path = os.path.join(self.cfp, log_name)
        size_limit = 5*1024*1024 # 5MB
        while os.path.isfile(log_path) and os.path.getsize(log_path) > size_limit:
            i+=1
            log_name = f"vpktools{i}.log"
            log_path = os.path.join(self.cfp, log_name)
        return open(log_path, "a", encoding="utf-8")
        
    def log(self, text):
        timestamp = time.strftime("%Y-%m-%d %H:%M:%S", time.localtime())
        self.logfile.write(f"{timestamp} {text}\n")
        self.logfile.flush()

    # Step-1 检测steam
    def check_steam_dir(self, path):
        if not os.path.isdir(path):
            return False
        while not os.path.exists(os.path.join(path, "steamapps")):
            path = os.path.dirname(path)
            if not path:
                return False
        exe_path = os.path.join(path, "steamapps", "common", "Left 4 Dead 2", "left4dead2.exe")
        addons_path = os.path.join(path, "steamapps", "common", "Left 4 Dead 2", "left4dead2", "addons")
        if not os.path.exists(exe_path) or not os.path.exists(addons_path):
            return False
        return addons_path

    # 注册表读取steam目录
    def reg_steam_dir(self):
        try:
            hkey = winreg.OpenKey(winreg.HKEY_LOCAL_MACHINE, r"SOFTWARE\WOW6432Node\Valve\Steam")
            steam_dir, reg_type = winreg.QueryValueEx(hkey, "InstallPath")
            winreg.CloseKey(hkey)
            if reg_type == winreg.REG_SZ and self.check_steam_dir(steam_dir):
                self.log(f"通过注册表检测到steam目录: {steam_dir}")
                return self.check_steam_dir(steam_dir)
            else:
                None
        except Exception as e:
            self.log(f"读取注册表失败: {e}")
            return None

    """
    预设路径检测steam
    C:\Program Files (x86)\Steam
    D:\Program Files\steam
    E:\steam
    F:\Steam
    """
    def walk_steam_dir(self):
        drives = [drive for drive in win32api.GetLogicalDriveStrings().split('\000') if drive]
        steam_name = ["Steam", "steam", "SteamLibrary"]
        program_files = ["Program Files", "Program Files (x86)"]
        # 预设路径
        candidates = [
            f"{drive}{os.path.sep}{program}{os.path.sep}{steam}"
            for drive in drives
            for program in program_files
            for steam in steam_name
        ]
        for drive in drives:
            for steam in steam_name:
                candidates.append(f"{drive}{os.path.sep}{steam}")
        # 校验
        for candidate in candidates:
            game_dir = self.check_steam_dir(candidate)
            if game_dir:
                self.log(f"通过预设路径检测到有效steam目录: {candidate}")
                return game_dir
        return None

    def auto_detect_steam(self):
        steam = self.reg_steam_dir()
        if steam:
            return steam
        return self.walk_steam_dir()

    # Step-2 确定vpk目录
    def check_vpk_dir(self, path):
        if not path or not os.path.isdir(path):
            return False
        # cfp
        for file in os.listdir(path):
            if file.endswith(".vpk"):
                return path
        # cfp/addons
        addons_path = os.path.join(path, "addons")
        if os.path.isdir(addons_path):
            for file in os.listdir(addons_path):
                if file.endswith(".vpk"):
                    return addons_path
        # cfp/workshop
        workshop_path = os.path.join(path, "workshop")
        if os.path.isdir(workshop_path):
            for file in os.listdir(workshop_path):
                if file.endswith(".vpk"):
                    return workshop_path
        # cfp/addons/workshop
        workshop_path = os.path.join(addons_path, "workshop")
        if os.path.isdir(workshop_path):
            for file in os.listdir(workshop_path):
                if file.endswith(".vpk"):
                    return workshop_path
        return False

    def copy_vpk(self):
        if not self.vpk_dir or not self.steam_dir:
            return False
        vpk_files = []
        remain_bytes = []
        for file in os.listdir(self.vpk_dir):
            if not file.endswith(".vpk"):
                continue
            vpk_files.append(file)
            # 获取文件大小
            remain_bytes.append(os.path.getsize(os.path.join(self.vpk_dir, file)))
            # 对应的jpg也要复制
            jpg_name = file.replace(".vpk", ".jpg")
            if os.path.exists(os.path.join(self.vpk_dir, jpg_name)):
                vpk_files.append(jpg_name)
                remain_bytes.append(os.path.getsize(os.path.join(self.vpk_dir, jpg_name)))
        # 总共需要复制的文件数量
        file_count = len(vpk_files)
        self.progress_label.pack()  # 显示进度条
        # 启动线程复制
        threading.Thread(target=self._copy_vpk_worker, args=(vpk_files, remain_bytes, file_count)).start()

    def _copy_vpk_worker(self, vpk_files, remain_bytes, file_count):
        total_copied = 0
        total_size = sum(remain_bytes)

        for i in range(file_count): 
            file = vpk_files[i]
            if os.path.exists(os.path.join(self.steam_dir, file)):
                self.log(f"{file}已存在,跳过")
                self.main_window.after(0,self.show, f"{i+1}/{file_count} {file}到{self.steam_dir}")
                total_copied += remain_bytes[i]
                remain_bytes[i] = 0
                continue

            self.log(f"复制{file}")
            self.main_window.after(0,self.show, f"{i+1}/{file_count} 正在复制{file}")

            try: 
                shutil.copy(os.path.join(self.vpk_dir, file), self.steam_dir)
                self.log(f"复制{file}成功")
                total_copied += remain_bytes[i]
            except Exception as e:
                self.log(f"复制文件{file}失败:{e}")

            # 更新进度
            self._update_progress(total_copied, total_size)

        self.main_window.after(0,self.show, f"{i+1}/{file_count} 复制完毕")
        self._update_progress(total_copied, total_size)

    def _update_progress(self, total_copied, total_size):
        if total_size == 0:
            percent = 100
            remaining_time = 0
        else:
            percent = (total_copied / total_size) * 100
            remaining_time = (total_size - total_copied) / max(1, total_copied / time.time())
        remain_mb = (total_size-total_copied)/1024/1024
        msg = f"进度: {percent:.2f}% 剩余大小{remain_mb:.2f}MB 剩余时间: {remaining_time:.2f}s"
        self.main_window.after(0, self.progress_text.set, msg)  # 使用 after() 来更新 UI

    def launch_game(self):
        self.copy_vpk()
        try:
            subprocess.Popen(["start", "steam://rungameid/550"], shell=True)
            self.log("游戏启动成功")
            return True
        except Exception as e:
            self.log(str(e))
            return False
    def select_vpk_dir(self):
        vpk_dir = filedialog.askdirectory(title="选择VPK存放目录")
        valid_vpk_dir = self.check_vpk_dir(vpk_dir)
        if valid_vpk_dir:
            self.vpk_dir = vpk_dir
            self.update()

    def select_game_dir(self):
        game_dir = filedialog.askdirectory(title="选择Left 4 Dead 2目录")
        addons_dir = self.check_steam_dir(game_dir)
        if addons_dir:
            self.steam_dir = addons_dir
            self.update()

    def update(self):
        if not self.steam_dir:
            self.lack_steam()
            self.show("【注意】未检测到steam,请")
            self.select_game_dir_btn.pack()
            return
        self.select_game_dir_btn.pack_forget()
        if not self.vpk_dir:
            self.show("【注意】未检测到vpk目录,请")
            self.select_vpk_dir_btn.pack()
            return
        self.select_vpk_dir_btn.pack_forget()
        self.show("已确定Left 4 Dead 2目录和VPK目录")
        self.log(f"Left 4 Dead 2目录:{self.steam_dir}")
        self.log(f"Vpk目录{self.vpk_dir}")
        self.launch_game_btn.pack()
        self.copy_vpk_btn.pack()


if __name__ == '__main__':
    # 创建一个唯一的互斥体
    mutex = win32event.CreateMutex(None, 0, "VpkToolsMutex")
    # 检查是否已有实例在运行
    if win32api.GetLastError() == 183:
        sys.exit()
    vpktools = VPKTools()
    vpktools.main_window.mainloop() 
