---
title: Github + Hexo 搭建博客(二)
date: 2018-9-26 23:32:51
tags: hexo
toc: hexo
---
{% asset_img hexoicon.jpg Hexo %}

# 3 创建Github SSH连接

Github支持https和ssh两种方式管理本地和远程代码的同步，作为个人repo的拥有者，推荐使用ssh方式，因为每次写博客上传远端库时可以省略用户名和密码的验证。

<!-- more -->

① 创建ssh key

```
$ ssh-keygen -t rsa -C "your_email@example.com"
```
"your_email@example.com"使用github个人账户邮箱，创建成功后连续三次回车，以下分别说明

```
Generating public/private rsa key pair.
# Enter file in which to save the key (/c/Users/you/.ssh/id_rsa): [Press enter]
```
第一次要求输入保存公钥和秘钥的文件路径，直接回车视为默认，保存在`/c/Users/you/.ssh/id_rsa`下

```
Enter passphrase (empty for no passphrase): 
# Enter same passphrase again:
```

接下来两年次回车是提交密码和密码确认，可以默认无密码。

> 当然，如果要设置密码需要说明，该密码仅为push本地代码到远端时的密码，而非账户密码，建议省略。

接下来，就会完成创建并保存到本地

```
Your identification has been saved in /c/Users/you/.ssh/id_rsa.
# Your public key has been saved in /c/Users/you/.ssh/id_rsa.pub.
# The key fingerprint is:
# 01:0f:f4:3b:ca:85:d6:17:a1:7d:f0:68:9d:f0:a2:db your_email@example.com
```

② 绑定ssh key

在保存路径下找到`id_rsa.pub`，打开并复制其中的内容

登录github，在个人`Setting`下找到`SSH and GPG keys` 并将复制的内容添加一个新的SSH Key。

至此，绑定ssh完毕

③ 测试ssh连接
在git bash中输入以下命令

```
$ ssh -T git@github.com

The authenticity of host 'github.com (207.97.227.239)' can't be established.
# RSA key fingerprint is 16:27:ac:a5:76:28:2d:36:63:1b:56:4d:eb:df:a6:48.
# Are you sure you want to continue connecting (yes/no)?
```

显示警告无妨，输入yes并继续，会得到最终测试的结果。

```
Hi username! You've successfully authenticated, but GitHub does not
# provide shell access.
```
如果显示`successfully authenticated`表示ssh授权成功，可以使用；

相反，如果提示`access denied`表示失败，可以删除已绑定的ssh并重新进行②步骤，注意粘贴内容不含其它字符包括空格和回车。

<br><br>

# 4 将初始化博客部署至github

上一节最终已经在本地初始化了hexo博客并且正常运行，接下来需要部署至github的仓库并通过互联网域名进行访问

① 首先，需要在根路径安装自动部署插件

```
d:\blog > npm install hexo-deployer-git --save
```

② 配置部署信息

首先，访问github，并在上节创建的仓库中找到专属SSH连接地址，复制该地址

{% asset_img step1.jpg %}

其次，在本地根路径下打开_config.yml文件，找到`deploy`对象并进行配置

{% asset_img step2.jpg %}

> 说明1：由于建议使用ssh方式，这里type和repo都是ssh连接。当然也支持https方式，在②中就需要复制https对应得到地址配置在此处

> 说明2：github搭载的hexo只支持上传master分支，如果上传其他自定义分支是无法正常显示的。所以branch配置master分支

> 说明3: yml文件特别需要注意冒号后的一个空格，如果疏忽则会导致配置出错。并且yml文件受到缩进的严格限制来进行归类，这区别于properties文件和json文件。

③ 自动化部

使用以下命令进行生成静态文件和部署操作。

```
d:\blog > hexo d -g
```
或者

```
d:\blog > hexo g

d:\blog > hexo d
```

当显示部署成功后,就可以通过上节中配置的域名`https:\\yourdomain.github.io`进行访问，当然，你也可以访问github仓库查看本次上传的全部内容。

---

> <h3>结尾</h3> `OK，你期望的美好正在发生，但是觉得页面太丑？或者我如何发布自己写的博客，这将在下节展开`