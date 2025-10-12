from typing import Any, Dict, List, Optional, Tuple
import requests
import os
import fire


class Chfs:
    """
    CuteHttpFileServer/chfs 文件服务器 client
    """
    
    def __init__(self, ip: str = "10.51.33.211", port: int = 10000, user: str = "admin", pwd: str = "admin") -> None:
        """
        初始化 Chfs 客户端

        Args:
            ip (str): chfs 服务器 IP
            port (int): chfs 服务器 Port
            user (str): 默认用户名
            pwd (str): 默认密码
        """
        self._ip, self._port = ip, port
        self._user = user
        self._pwd = pwd
        self._session = requests.Session()
        # 自动登录
        self.login(self._user, self._pwd)


    def _getUrl(self, endpoint: str):
        return f"http://{self._ip}:{self._port}/chfs/{endpoint}"


    def login(self, user: str, pwd: str) -> bool:
        """
        账户登录

        Args:
            user (str): 用户名
            pwd (str): 密码

        Returns:
            bool: 登录结果
        """
        login_data = {"user":user, "pwd":pwd}
        resp = self._session.post(self._getUrl("session"), data=login_data)
        if not resp.ok: print(resp.reason)
        return resp.ok


    def logout(self) -> bool:
        """
        账户登出

        Returns:
            bool: 登出结果
        """
        resp = self._session.delete(self._getUrl("session"))
        return resp.ok
        

    def downloadFile(self, fileUrl:str, savePath:Optional[str]=None) -> bool:
        """
        下载文件

        Args:
            fileUrl (str): 文件在服务器上的路径
            savePath (Optional[str], optional): 要保存的路径. Defaults to None.

        Returns:
            bool: 下载文件结果
        """
        resp = self._session.get(self._getUrl(fileUrl), stream=True)

        # 检查请求是否成功
        resp.raise_for_status()
        
        # 如果未提供保存路径，从URL中提取文件名
        if savePath is None:
            # 从URL中提取文件名，处理URL编码
            filename = os.path.basename(fileUrl.split('?')[0])
            savePath = os.path.join(os.getcwd(), filename)
        
        # 确保保存目录存在
        os.makedirs(os.path.dirname(savePath), exist_ok=True)
        
        # 获取文件大小（如果有）
        fileSize = int(resp.headers.get('content-length', 0))
        
        print(f"开始下载: {fileUrl}")
        print(f"保存路径: {savePath}")
        print(f"文件大小: {fileSize / (1024 * 1024):.2f} MB")
        
        # 流式下载，避免一次性加载大文件到内存
        with open(savePath, 'wb') as f:
            downloaded = 0
            for chunk in resp.iter_content(chunk_size=8192):
                if chunk:  # 过滤掉保持连接的新块
                    f.write(chunk)
                    downloaded += len(chunk)
                    
                    # 显示下载进度
                    if fileSize > 0:
                        percent = (downloaded / fileSize) * 100
                        print(f"\r下载进度: {percent:.1f}%", end='')
                    else:
                        print(f"\r已下载: {downloaded / (1024 * 1024):.2f} MB", end='')
        
        print("\n下载完成!")
        return True




    def deleteFile(self, filePath:str) -> bool:
        """
        删除文件    

        Args:
            filePath (str): 文件路径

        Returns:
            bool: 删除文件的结果
        """
        resp = self._session.delete(self._getUrl(f"rmfiles?filepath={filePath}"))
        if not resp.ok: print(resp.reason)
        return resp.ok
    

    def uploadFile(self, filePath: str, destPath: str = "/") -> bool:
        """
        上传文件到指定路径
        
        Args:
            filePath (str): 要上传的本地文件路径
            destPath (str): 目标目录路径，默认为根目录"/"
            
        Returns:
            dict: 服务器响应的JSON数据，如果上传失败则返回None
        """
        try:
            # 检查文件是否存在
            if not os.path.exists(filePath):
                print(f"错误: 文件 {filePath} 不存在")
                return False
            
            # 获取文件名
            filename = os.path.basename(filePath)
            
            # 确保目标路径格式正确
            destPath = destPath.rstrip('/')
            if destPath == "":
                destPath = "/"
            
            # 获取文件大小
            fileSize = os.path.getsize(filePath)
            print(f"准备上传文件: {filename}")
            print(f"文件大小: {fileSize / (1024 * 1024):.2f} MB")
            print(f"目标路径: {destPath}")
            
            # 准备文件
            with open(filePath, 'rb') as f:

                files = {'file': (filename, f)}                
                data = {'folder': destPath}
                
                uploadUrl = self._getUrl(f"upload")
                print(f"上传中... {uploadUrl}")
                resp = self._session.post(uploadUrl, files=files, data=data)
            
            # 检查响应状态
            resp.raise_for_status()
            if not resp.ok: print(resp.reason)
            return resp.ok
                
        except requests.exceptions.RequestException as e:
            print(f"上传失败: {e}")
            if e.response:
                print(f"服务器响应: {e.response.text}")
            return False
        except Exception as e:
            print(f"发生错误: {e}")
            return False



    def mkdir(self, dirPath: str) -> bool:
        """
        创建文件夹

        Args:
            dirPath (str): 文件夹路径

        Returns:
            bool: 创建文件夹结果
        """
        resp = self._session.post(self._getUrl("newdir"), data={"filepath":dirPath})
        if not resp.ok: print(resp.reason)
        return resp.ok


    def getListsOfDirs(self, path:str) -> Tuple[Optional[List[Any]], Optional[List[Any]]]:
        """
        获取文件夹下内容列表

        Args:
            path (str): 指定的文件夹路径

        Returns:
            Tuple[Optional[List[Any]], Optional[List[Any]]]: 指定的文件夹路径下的文件列表, 指定的文件夹路径下的文件夹列表
        """
        resp = self._session.get(self._getUrl(f"files?filepath={path}"))
        if resp.ok:
            jsonData:dict = resp.json()
            files:List[Any] = [] 
            dirs:List[Any] = []
            for item in jsonData.get("files", []):
                item:dict
                if item.get("dir", False):
                    dirs.append(item.get("name"))
                else:
                    files.append(item.get("name"))
            print(f"files:{files},dirs:{dirs}")
            return files, dirs
        return None, None


def main():
    fire.Fire(Chfs)


if __name__ == "__main__":
    main()
