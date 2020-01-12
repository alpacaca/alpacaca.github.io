---
title: Github + Hexo 搭建博客(一)
date: 2018-09-19 23:30:29
tags: hexo
toc: hexo
---
{% asset_img hexoicon.jpg Hexo %}

# 1 申请Github的page域名
访问[Github](https://github.com)官网新建账号，并创建个人仓库。

<!--more-->



在个人仓库操作框下进行设置`settings`，要满足三级域名要求必须进行如下操作。

> `Repository name` 必须保证三级域名与账号一致，且以io顶级域名结束，否则访问路径会出现在路径分隔符后。例如：正常域名:`alpacaca.github.io`；错误域名`www.github.com/alpacaca/xxxblog`


{% asset_img step1.jpg %}

如果正确创建，在`GitHub Pages`中正确显示已经发布的域名地址

{% asset_img step2.jpg %}

可以在个人repo的master分支中创建readme.md用作说明或提示类信息（不要求）。

下载Github工具，安装带有Github Bash的命令提示符。

<br ><br >

# 2 配置环境并下载Hexo

`Hexo下载安装依赖npm，npm是nodejs包管理器，nodejs安装依赖python环境`

[下载](https://www.python.org/)python3版本并安装，在环境变量path中添加python解释器的路径。添加项应是安装路径下的python3.exe

[下载](https://nodejs.org/en/)stable稳定版nodejs并安装，需要安装npm包管理器。使用以下命令查看npm 和node的版本是否正确。

```node
user > npm -v
user > node -v
```


（由于万里长城的原因，npm默认中央仓库可能无法正常访问或者加载速度过慢）这时，需要通过以下命令查看`metrics-registry`参数

```node
user > npm config list
```

taobao提供国内npm仓库镜像`https://registry.npm.taobao.org/`，可以通过以下命令设置。
```node
user > npm config set registry http://registry.npm.taobao.org/
```

此时，nodejs和npm的准备工作已经完成。

通过npm安装hexo
```node
#(此处为注释，下同)全局安装hexo组件
user > npm install hexo -g  

#安装完毕查看hexo版本
user > hexo -v
```

可以通过cmd进入硬盘任意位置 或者 在任意位置通过地址栏输入cmd打开命令提示符，初始化hexo组件、安装并初次运行
```node
# 初始化hexo组件
d:\blog > hexo init

# 安装依赖组件
d:\blog > npm install

# 当全部完成后，生成静态文件
d:\blog > hexo g

# 本地浏览
d:\blog > hexo s -o
# hexo默认端口4000，如果此处端口被占用，可以使用下列命令，xxx为自定义端口
d:\blog > hexo s -o -p xxx
```

至此，当在浏览器中出现下图，表示hexo已经在本地可以完美运行。接下来需要发布blog到Github，并在互联网上进行访问。

{% asset_img step3.jpg Hexo %}

---

> <h3>结尾</h3>`本地初始化博客已经跑起来了，如何部署到远端通过互联网域名方式访问，将在下节展开`