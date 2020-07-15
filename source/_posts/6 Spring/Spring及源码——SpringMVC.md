---
title: Spring及源码——SpringMVC
date: 2020-6-15
tags: [Spring]
---
{% asset_img image1.jpg spring %}

# Spring及源码——SpringMVC
<!--more-->

## 2 SpringMVC

### 2.1 Spring容器 和 SpringMVC容器的加载过程

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;在Spring创建Web系统应用过程中会启动两个容器，分别是基础容器（Root IOC）用于保存业务 Bean 和 Web容器用于保存Web相关组件Bean，例如处理器、适配器和解析器等。Root IOC 是 Web容器的父容器，通过这样的继承关系使两个容器产生了关联关系，即父容器无法访问子容器的组件，子容器可以访问父容器的组件。

> 通常我们称web系统服务器为web容器，例如tomcat、apache、jetty、undertow等，为了加以区别：
>
> Spring基础容器称为 root ioc；
>
> SpringMVC容器称为 web ioc；
>
> web容器表示tomcat等系统应用的名称。



{% asset_img init.png springmvc%}



具体创建步骤如下：

1. 启动web容器，加载web容器目录内的server.xml配置，创建ServletContext全局对象。

2. 加载工程内web.xml文件，首先加载\<context-param>下的Spring根配置文件路径并保存在ServletContext中。

3. 加载 Spring 的 ContextLoaderListener ，如果ServletContext已创建则读取 context-param 内的配置文件路径，并创建 Spring 容器 Root IOC ，创建成功后将该容器注册到ServletContext的属性列表中，关键字 key 为 ROOT_WEB_APPLICATION_CONTEXT_ATTRIBUTE，在随后的使用过程中可以从ServletContext中读取ROOT IOC。

4. 加载 web.xml 中的 \<servlet>，这里既可以加载自定义的 Servlet ，但主要加载 DispatcherServlet ，Spring支持创建多个 DispatcherServlet 用于处理不同的请求，每一个 DispatcherServlet 都会创建各自**独占**的 Web IOC （Web IOC 配置文件路径通过 \<init-param> 设置）， Web IOC 会将 Root IOC 设为父容器，这样在处理 Web 应用过程中就可以获得 Root IOC 内的业务 Bean 信息。Root IOC 是无法访问 Web IOC 内信息的。创建好的 Web IOC 也会添加到 ServletContext 的属性列表中，关键字 key 为 ServletName。

   

   > Web IOC 注册到ServletContext中的关键字其实并不仅仅是Servlet Name，具体源码如下。

   

   ```java
   // Spring 源码
   public class FrameworkServlet {
       public static final String SERVLET_CONTEXT_PREFIX = FrameworkServlet.class.getName() + ".CONTEXT.";
       
       protected WebApplicationContext initWebApplicationContext() { 
           ...
               
           if (this.publishContext) {
               String attrName = this.getServletContextAttributeName();
               this.getServletContext().setAttribute(attrName, wac);
           }
           
           ...
       }
       
       public String getServletContextAttributeName() {
           return SERVLET_CONTEXT_PREFIX + this.getServletName();
       }
   }
   ```



5. 初始化 Web IOC 策略 Bean 对象，其中主要包括：HandlerMapping、HandlerAdapter、ViewResolvers等解析器、映射器和适配器，最终整个装载过程完成。

   ```java
   // spring 源码
   protected void initStrategies(ApplicationContext context) {
       initMultipartResolver(context);		// 上传文件解析
       initLocaleResolver(context);		// 本地解析
       initThemeResolver(context);			// 主题解析
       initHandlerMappings(context);		// url映射器
       initHandlerAdapters(context);		// 映射器的目标执行对象，通过适配器执行
       initHandlerExceptionResolvers(context); 	// 异常解析
       initRequestToViewNameTranslator(context);
       initViewResolvers(context);			// 视图解析器
       initFlashMapManager(context);
   }
   ```

   

### 2.2 SpringMVC 框架执行过程



{% asset_img springmvc.png springmvc%}



1. 客户端发出请求到web容器。

2. web容器解析url并找到适配的servlet，此处转发给DispatcherServlet处理。

3. DispatcherServlet 解析 url 并通过 HandlerMapping 找到适配的处理器Handler。

4. HandlerAdapter 将对应的 Handler封装为适配器，并进行业务处理，处理结束后会以 ModelAndView对象返回。

5. DispatcherServlet 解析 ModelAndView 中的 View 路径，并通过 ViewResolver 解析获得对应的视图View。

6. 将 ModelAndView 中的数据与对应的视图 View 进行渲染并最终返回给客户端。

   

### 2.3 相关注解

**@Controller 、 @RestController 和 @AsyncRestController**

三者都可以放置在类注解，表示当前类是控制层Bean对象，@Controller表示的控制器返回时要求是 ModelAndView 对象，只返回字符串则表示视图关键字，用于下一步通过视图解析器获得对应视图，如果只希望返回给客户端字符串内容需要配合 **@ResponseBody** 使用； @RestController 简化了该过程，实际上就是@Controller 和 @ResponseBody的组合形式；该两者控制器在处理过程中都是同步阻塞式执行，而 @AsyncRestController 属于异步非阻塞式控制器。



**@RequestMapping 和 Rest风格控制器**

SpringMVC 的重要责任之一就是通过解析 url 匹配对应的控制器，@RequestMapping 负责执行匹配逻辑。该注解既可以使用在类层，也可以使用在方法层。当使用在类层时表示上层路径匹配项，该类中的方法层匹配都受此约束；当使用在方法层时表示最终的匹配项，通过 HandlerMapping 可以最终找到映射的处理器。

在早先开发过程中，客户端请求无非 Get 和 Post 两种类型处理，而实际上 HttpRequest 还包含 Put、Delete、Patch、Option、Trace 和 Head。Rest 要求应该严格按照 Http 请求类型来处理对应的业务逻辑，比如 Get类型负责查询、Post类型负责新增、Put类型负责更新、Delete类型负责删除。这就要求在使用 @RequestMapping时应该注明对应的请求类型，如`@RequestMapping(method = RequestMethod.GET)`。

@RequestMapping 支持表达式声明，以下表达式都是合法的且可以通过@PathVariable 获得路径中的占位符：

- /user/*/add  :  匹配/user/xxx/add、/user/yyy/add等;
- /user/**/add ：匹配/user/xxx/yyy/add、/user/add等；
- /user/add?? :  匹配/user/addXXX、/user/addYYY等；
- /user/{id} :  匹配/user/123等；
- /user/**/{id} : 匹配/user/123、/user/find/123等；
- /user/{userId}/job/{jobId}/kpi/{kpiId} :  匹配/user/123/job/456/kpi/789等；



**@PathVariable、@RequestParam、@RequestBody**

通常客户端请求传参过程中，简单参数可以直接在控制器入参中进行转换，当采用路径参数时使用@PathVariable获取；当传递多参数时可以使用@RequestParam进行处理；当传递的是json等对象时，可以使用@RequestBody接收并处理。

```java
@RequestMapping(value = "/user/{id}", method = RequestMethod.GET)
public void demo1 (@PathVariable int id) {
	...
}

@RequestMapping("/user")
public void demo2 (@RequestParam("id") int id, @RequestParam("name") String name) {
	...
}

@RequestMapping(value = "/user", method = RequestMethod.POST)
public void demo3 (@RequestBody Object input) {
	...
}
```



> 在使用@PathVariable时特别注意，一般情况下匹配项应该指定获取路径变量名，如
>
> @RequestMapping("\user\\{id}")
>
> public void demo(@PathVarable("id") int id) {...}
>
> 通过指定 id 来获得路径变量 id 的值。
>
> 不指定路径变量名，就会通过注解标记的参数名当作路径变量名使用。
>
> 但我们知道，在反射调用中参数名是无法获得的（因为在字节码 或 JVM常量池中 并不会保存形参的元数据），所以在JAVA8及以上版本中，通过IDE中配置编译命令 `javac -parameters`来使该功能可用。



**简化Rest风格注解**

标准的的 REST 注解应该是这样`RequestMapping(value = "/user", method = RequestMethod.POST)`，但为了追求更快速和极简的风格可以采用简化版的注解：**@GetMapping("/user")、 @PostMapping("/user")、@PutMapping("/user")、@DeleteMapping("/user")、@PatchMapping("/user")。**