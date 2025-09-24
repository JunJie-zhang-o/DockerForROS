
#!/usr/bin/sh
###
 # @Author       : jay jay.zhangjunjie@outlook.com
 # @Date         : 2025-09-23 20:53:22
 # @LastEditTime : 2025-09-23 20:53:25
 # @LastEditors  : jay jay.zhangjunjie@outlook.com
 # @Description  : 
### 


docker build --platform=linux/amd64 --build-arg UID=$(id -u) --build-arg GID=$(id -g) -t u2204ros1:latest .