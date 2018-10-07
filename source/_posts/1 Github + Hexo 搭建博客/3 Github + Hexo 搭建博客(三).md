---
title: Github + Hexo 搭建博客(三)
date: 2018-9-30 21:18:06
tags: hexo
toc: hexo
---
{% asset_img hexoicon.jpg Hexo %}

# 5 Hexo全局配置

初次浏览全局配置文件，在本地根目录下找到_config.yml文件

<!-- more -->

```yml
# Hexo Configuration
## Docs: https://hexo.io/docs/configuration.html
## Source: https://github.com/hexojs/hexo/

# Site
title: zhy's blog
subtitle: Stay Hungry , Stay Foolish
description:
keywords: zhy blog
author: zhy
language: zh-Hans
timezone:

# URL
## If your site is put in a subdirectory, set url as 'http://yoursite.com/child' and root as '/child/'
url: http://yoursite.com
root: /
permalink: :year/:month/:day/:title/
permalink_defaults:

# Directory
source_dir: source
public_dir: public
tag_dir: tags
archive_dir: archives
category_dir: categories
code_dir: downloads/code
i18n_dir: :lang
skip_render:

# Writing
new_post_name: :title.md # File name of new posts
default_layout: post
titlecase: false # Transform title into titlecase
external_link: true # Open external links in new tab
filename_case: 0
render_drafts: false
post_asset_folder: true
relative_link: false
future: true
highlight:
  enable: true
  line_number: true
  auto_detect: false
  tab_replace:
  
# Home page setting
# path: Root path for your blogs index page. (default = '')
# per_page: Posts displayed per page. (0 = disable pagination)
# order_by: Posts order. (Order by date descending by default)
index_generator:
  path: ''
  per_page: 10
  order_by: -date
  
# Category & Tag
default_category: uncategorized
category_map:
tag_map:

# Date / Time format
## Hexo uses Moment.js to parse and display date
## You can customize the date format as defined in
## http://momentjs.com/docs/#/displaying/format/
date_format: YYYY-MM-DD
time_format: HH:mm:ss

# Pagination
## Set per_page to 0 to disable pagination
per_page: 10
pagination_dir: page

# Extensions
## Plugins: https://hexo.io/plugins/
## Themes: https://hexo.io/themes/
theme: yilia

# Deployment
## Docs: https://hexo.io/docs/deployment.html
deploy:
  type: git
  repo: git@github.com:alpacaca/alpacaca.github.io.git
  branch: master

```

> <h3>注意：</h3>yml文件相比于properties配置文件，更加简洁。类似于python代码，主从配属严格受到缩进的影响，特别特别需要强调的是，配置名后的冒号和参数之间是一定有空格的！

接下来分别认识一下配置文件。

## 站点和url配置
```yml
# Site
title: zhy's blog
subtitle: Stay Hungry , Stay Foolish
description:
keywords: zhy blog
author: zhy
language: zh-Hans
timezone:

# URL
## If your site is put in a subdirectory, set url as 'http://yoursite.com/child' and root as '/child/'
url: http://yoursite.com
root: /
permalink: :year/:month/:day/:title/
permalink_defaults
```
- title ， 是浏览器标签显示的名字
- subtitle ， 子标题
- keywords ， 主要用于SEO，可以采用列表表示[key1,key2],下同
- author, 作者
- language:  初次加载根据pc环境选择，可以手动修改
- timezone： 时区，默认同系统

> <h3>说明</h3> 如果你部署的博客地址并非三级以内的域名，而是地址分割符后的，比如`http://github.com/alpacaca`，那么需要配置url信息，如下

- url： 默认不变，如果是地址分割符后地址需要配置`http://yoursite.com/child`
- root: /child/
- permalink: 永久链接

## 目录

```yml
# Directory
source_dir: source
public_dir: public
tag_dir: tags
archive_dir: archives
category_dir: categories
code_dir: downloads/code
i18n_dir: :lang
skip_render:
```
- source_dir	资源文件夹，这个文件夹用来存放内容。	
- public_dir	公共文件夹，这个文件夹用于存放生成的站点文件。	
- tag_dir	标签文件夹	
- archive_dir	归档文件夹	
- category_dir	分类文件夹	
- code_dir	Include code 文件夹	
- i18n_dir	国际化（i18n）文件夹	
- skip_render	跳过指定文件的渲染，可使用 glob 表达式来匹配路径。	

## 写作
```yml
# Writing
new_post_name: :title.md # File name of new posts
default_layout: post
titlecase: false # Transform title into titlecase
external_link: true # Open external links in new tab
filename_case: 0
render_drafts: false
post_asset_folder: true
relative_link: false
future: true
highlight:
  enable: true
  line_number: true
  auto_detect: false
  tab_replace:
```

- new_post_name	新文章的文件名称
- default_layout	预设布局
- auto_spacing	在中文和英文之间加入空格
- titlecase	把标题转换为
- external_link	在新标签中打开链接
- filename_case	把文件名称转换为 (1) 小写或 (2) 大写
- render_drafts	显示草稿	
- post_asset_folder	启动 Asset 文件夹	
- relative_link	把链接改为与根目录的相对位址	
- future	显示未来的文章
- highlight	代码块的设置	

## 分页、主题和部署
```yml
# Pagination
## Set per_page to 0 to disable pagination
per_page: 10
pagination_dir: page

# Extensions
## Plugins: https://hexo.io/plugins/
## Themes: https://hexo.io/themes/
theme: yilia

# Deployment
## Docs: https://hexo.io/docs/deployment.html
deploy:
  type: git
  repo: git@github.com:alpacaca/alpacaca.github.io.git
  branch: master
```

- per_page 每页显示博客数
- pagination_dir 分页目录
- theme 主题，将在下节介绍
- deploy 部署

> <h3>关于deploy</h3>当安装了hexo部署插件后，可以通过配置deploy自动进行部署，我选择的是以git方式发布到repo中的master分支

<br/> <br />

# 6 主题的选择和配置

如果不喜欢Hexo的默认主题（没有人会喜欢[doge]），官方还提供了大量的主题类型，可以[访问这里](https://hexo.io/themes/)选择自己认为ok的主题

> <h3>比如：</h3>中意首页展示的[Aria主题](https://sh.alynx.xyz/)，那么你可以在最下方footer标签范围找到该主题对应托管在github上的[资源](https://github.com/AlynxZhou/hikaru-theme-aria/)<br>clone该项目到本地根目录下的themes文件夹下。

首先，需要在根目录下的/_config.yml中配置theme指定aria

```yml
# Extensions
## Plugins: https://hexo.io/plugins/
## Themes: https://hexo.io/themes/
theme: aria
```

之后进入主题内的置/themes/aria/_config.yml文件中进行自定义配置

> <h3>关于主题</h3>这里就不展开了，因为不同的主题都有各自不同的配置要求，具体说明可以在打开的github资源首页READEME.md下找到

当配置完之后可以本地查看修改后的状态，运行
```cmd
d:\blog > hexo s -o
```

> <h3>结尾</h3> 
> `经过定制化的个人博客成功运行，你可以动手写文章啦！什么？你还不知道怎么写？那么我们下一节介绍具体介绍。`

> `目前博客的书写均采用MarkDown进行编辑，如果你已经掌握可以跳过下节`