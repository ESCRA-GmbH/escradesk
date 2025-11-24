import os
from subprocess import call 

command = "rmdir -r C:\\Users\\User\\AppData\\Roaming\\RustDesk\\"
# os.system('cmd /c "rmdir -r C:\\Users\\User\\AppData\\Roaming\\RustDesk\\"\\' )
call(command, shell=True)

command = "rmdir -r C:\\Windows\\ServiceProfiles\\LocalService\\AppData\\Roaming\\RustDesk\\"
call(command, shell=True)

#os.system('cmd /c "rmdir -r C:\Windows\ServiceProfiles\LocalService\AppData\Roaming\RustDesk\"')

command = "rmdir -r C:\\Users\\User\\AppData\\Local\\rustdesk\\"
call(command, True)

print("end of the program")
# os.system('cmd /c "rmdir -r C:\Users\User\AppData\Local\rustdesk"')