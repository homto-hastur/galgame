import ctypes
import time

# Show a Windows notification using the native API
def show_notification(title, message):
    ctypes.windll.user32.MessageBoxW(0, message, title, 0x40 | 0x1000)

if __name__ == "__main__":
    show_notification("任务完成提醒", "任务已完成！请打开 Cursor 继续工作。")
