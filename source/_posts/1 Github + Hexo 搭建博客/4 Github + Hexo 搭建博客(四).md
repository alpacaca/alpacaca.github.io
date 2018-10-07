---
title: Github + Hexo 搭建博客(四)
date: 2018-10-2 11:57:24
tags: hexo
toc: hexo
---
{% asset_img hexoicon.jpg Hexo %}


# 7 Hexo写作和Markdown

首先介绍Hexo博客的原理：本地编辑好的文本通过`hexo generate`命令，编译为静态html文本并发布到远端展示。换句话说，Hexo展示的内容都是Html文本形式的，这就意味着在本地编写的文本支持编译html。<br/><br/>

<!-- more -->

这就引入了Markdown文本编辑<br/><br/>

Markdown，是一种可以使用普通文本编辑器编写的标记语言，通过简单的标记语法，它可以使普通文本内容具有一定的格式(无法访问wiki，摘自百度百科解释)。<br/>

对于Markdown写作的规范和优势，可以自行百度，这里不多做解释，只需要记住一点，Markdown可以让我们更加关注内容的编写而不用花费更多精力在格式排版上。

既然作为标记语言，那么同样支持W3C规范的html标签。
> <h3>比如:<h3>
> 一级标题、二级标题、三级标题等对应的Markdown格式为`#一级标题`、`##二级标题`、`###三级标题`<br/>
> 也可以使用Html标签`<h1>一级标题<h1>`、`<h2>二级标题<h2>`、`<h3>三级标题<h3>`

## Markdown文本编辑工具

由于我个人在此之前长期使用**印象笔记**记录内容，搭配使用的是(马克飞象)[https://maxiang.io]Markdown编辑工具，良好的支持本地活在线编辑并和印象同步内容，然而马克飞象并不是当做其他md文本编辑的好工具。<br><br>

在使用了一众md编辑工具后，最终还是选择安利Visual Studio Code。VS Code本身并不是md工具，只是微软做出来与WebStorm抗衡的前端IDE，然而它实在是太优秀了，并且很好的支持Markdown的编辑工作，甚至hexo根目录下的yml文本、前端各种文本都可以编辑和展示，软件反应灵敏且安装容量极小，这就让我爱不释手。<br><br>

> <h3>注意：<h3>
> 不同的md编辑工具可能某些语法并不相同，比如Latex公式、表格甚至链接和图片等。但总的md标记不变，只是在不同工具上渲染出的效果不一样.<br>
> 这就好比不同的浏览器，内核不同，渲染出的网页效果也有一定的出入。具体最终渲染出的效果什么样还要遵循Hexo的md规范。

# 写作

## 新建写作
Ok，假设你已经掌握了md的基本语法，我们接下来可以正式进入编写博客了。<br><br>

```
d:\blog > hexo new myblog
```
使用该命令创建一个新的文章，myblog会保存在_posts文件中，该文件是博客存放和最终编译静态标记文本的路径。当然你也可以使用如下命令创建本次草稿，并最终移动到_posts下发布到远端（个人不推荐，原因是麻烦且没必要）
```
d:\blog > hexo new draft myblog   #创建草稿myblog并在draft文件下保存

# 编写草稿内容，完成后执行

d:\blog > hexo publish [scaffold]   #将草稿移动到_posts下，也可指定scaffold模板
```

## 写作模板说明
```
---
title: Github + Hexo 搭建博客(四)
date: 2018-9-30
tags: hexo
toc: hexo
---
# 内容
```
目前我采用的写作头文件是这样：
- `title`: 表示文章的标题，也是在博客首页最上方醒目显示的地方。
- `date`： 文章写作时间
- `tags`: 本所所属的标签，标签可以是单个标签，也可以是标签序列，如`tags: [github, hexo, blog]`,需要在根目录的_config.yml中开启标签支持
- `toc`： 文章目录。

申明头部之后，就可以在下方开始使用md书写内容了。

## 博客内图片

Markdown内的图片常规引入方式为使用标记`![text](imgurl)`，然而在hexo中并不适用，这也是标记不一致的地方，由于Hexo要生成静态页面，需要在同级目录中创建保存静态文件的文件夹。具体方式如下：<br>
在根目录_config.yml中配置
```
post_asset_folder: true
```
在使用命令`d:/blog > hexo new myblog`后会在同级目录中创建同名文件夹，将需要引入文章的图片保存在该文件夹中并命名，比如test.jpg。在md文本中使用如下命令引入
```
{% asset_img test.jpg Hexo %}
```

## 创建博客评论功能之——Gitment

登录[Gitment](https://github.com/settings/applications/new)进行注册，注册成功后会获得`client_id`和`client_secret`,进入主题下的_congif.yml配置如下：
```
gitment_owner: alpaca      #你的 GitHub ID
gitment_repo: 'https://alpacaca.github.io/'          #存储评论的 repo
gitment_oauth:
  client_id: 'xxx'           #client ID
  client_secret: 'xxx'       #client secret
```

配置成功后文章底部就会支持Gitment评论功能。

> <h3>注意：<h3>
> Gitment目前只能登录git账号后才能评论
> 切勿滥用！可以看[这里](https://imsun.net/posts/gitment-introduction/)

> <h3>结尾</h3> 
> `Github + Hexo搭建博客，暂且告一段落。当然，有深度定制Hexo需求甚至自建风格都可以参照官方文档进行开发，或者可以通过修改主题内的ejs文件和css文件。`
