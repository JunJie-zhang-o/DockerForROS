
#!/usr/bin/sh
###
 # @Author       : jay jay.zhangjunjie@outlook.com
 # @Date         : 2025-09-23 20:43:00
 # @LastEditTime : 2025-09-23 20:43:05
 # @LastEditors  : jay jay.zhangjunjie@outlook.com
 # @Description  : 
### 


/home/zhangjunjie/00-zj-humanoid/00-Ros1Space

docker run -itd --privileged -e DISPLAY=${DISPLAY} -v /tmp/.X11-unix:/tmp/.X11-unix -v /home/zhangjunjie/00-zj-humanoid/00-Ros1Space:/home/ros/00-Ros1Space -v /dev:/dev --net ros_network --ip 192.168.50.60 --name u22ros1 u2204ros1:latest