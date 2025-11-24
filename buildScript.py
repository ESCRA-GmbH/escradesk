import os
from subprocess import call 

if os.path.isfile("rustdesk-1.2.3-install.exe"):
    os.remove("rustdesk-1.2.3-install.exe")

if os.path.isfile("rustdesk_portable.exe"):
    os.remove("rustdesk_portable.exe")

call(["python", "build.py", "--flutter"])
