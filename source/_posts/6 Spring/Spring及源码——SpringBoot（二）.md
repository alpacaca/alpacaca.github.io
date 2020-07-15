---
title: Spring及源码——SpringBoot（二）
date: 2020-7-1
tags: [Spring, SpringBoot]
---
{% asset_img image1.jpg spring %}

# Spring及源码——SpringBoot（二）
<!--more-->

## 6 SpringBoot如何实现无 web.xml 启动

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;在 Servlet 发展史上，每个 web 容器都是通过加载 web.xml 来启动，在 web.xml 中定义了若干参数配置、监听器、过滤器以及Servlet，通过容器实例化后将对象保存在 ServletContext 中供全局使用。在 tomcat8 版本中开始全面采用全新的 **Servlet 3.1** 规范，规范中包含 **以代码方式配置 web 容器**。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;通过查阅 Spring 示例文档，其中提到了无参数配置，并给出了如下的例子：

```java
public class MyWebApplicationInitializer implements WebApplicationInitializer {

    @Override
    public void onStartup(ServletContext servletCxt) {

        // Load Spring web application configuration
        // 创建 ioc 容器
        AnnotationConfigWebApplicationContext ac = new AnnotationConfigWebApplicationContext();
        ac.register(AppConfig.class);
        ac.refresh();

        // Create and register the DispatcherServlet
        //基于java代码的方式初始化DispatcherServlet
        DispatcherServlet servlet = new DispatcherServlet(ac);
        // 动态创建 Servlet 并向 ServletContext 属性列表中注册对象。
        ServletRegistration.Dynamic registration = servletCxt.addServlet("app", servlet);
        registration.setLoadOnStartup(1);
        registration.addMapping("/app/*");
    }
}
```

这个例子虽然简单，但可以看出来 springboot 是如何在不配置 web.xml 情况下向 ServletContext 注册 Servlet 对象。在 springboot 应用实际启动中是通过 `DispatcherServletAutoConfiguration ` 自动装配来实现的。



## 7 SpringBoot 在 web 领域的应用

### 7.1 加载静态文件

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;在 **WebMvcAutoConfiguration** 自动配置类中，定义了资源加载的过程，其中首先会从配置中读取静态资源加载位置 `spring.mvc.static-path-pattern=` ，也是最常用的方法，其次在没有配置路径时先通过 **/webjars/\*\*** 加载静态资源

```java
public class WebMvcAutoConfiguration {
    public void addResourceHandlers(ResourceHandlerRegistry registry) {
        // 1. 配置了静态资源路径
        if (!this.resourceProperties.isAddMappings()) {
            logger.debug("Default resource handling disabled");
        } else {
            Duration cachePeriod = this.resourceProperties.getCache().getPeriod();
            CacheControl cacheControl = this.resourceProperties.getCache().getCachecontrol().toHttpCacheControl();
            // 2. 从 /webjars/** 下加载静态资源
            if (!registry.hasMappingForPattern("/webjars/**")) {
                this.customizeResourceHandlerRegistration(registry.addResourceHandler(new String[]{"/webjars/**"}).addResourceLocations(new String[]{"classpath:/META-INF/resources/webjars/"}).setCachePeriod(this.getSeconds(cachePeriod)).setCacheControl(cacheControl));
            }

            // 3. 从mvc参数配置类中加载路径
            String staticPathPattern = this.mvcProperties.getStaticPathPattern();
            if (!registry.hasMappingForPattern(staticPathPattern)) {
                this.customizeResourceHandlerRegistration(registry.addResourceHandler(new String[]{staticPathPattern}).addResourceLocations(WebMvcAutoConfiguration.getResourceLocations(this.resourceProperties.getStaticLocations())).setCachePeriod(this.getSeconds(cachePeriod)).setCacheControl(cacheControl));
            }

        }
    }
    
    // ...
}
```



**webjars**

> webjars支持以 maven 依赖的方式引入静态文件，以该方法引入的静态文件路径需要满足：classpath:/META-INF/resources/webjars/ 的约束。

```xml
<!-- 通过 maven 依赖引入静态文件 -->
<dependency>
	<groupId>org.webjars</groupId>
    <artifactId>jquery</artifactId>
    <version>3.4.1</version>
</dependency>
```

在路径 `classpath:/META-INF/resources/webjars/jquery/3.4.1/jquery.js` 就会在工程中存在。



**配置类路径加载**

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;在配置类路径中以如下路径优先级加载："classpath:/META-INF/resources/" > "classpath:/resources/" >  "classpath:/static/" > "classpath:/public/"。

```java
public class ResourceProperties {
    private static final String[] CLASSPATH_RESOURCE_LOCATIONS = new String[]{"classpath:/META-INF/resources/", "classpath:/resources/", "classpath:/static/", "classpath:/public/"};
    
    // ...
}
```



### 7.2  欢迎页的定制

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; 在 **WebMvcAutoConfiguration** 自动配置类中可以定义欢迎页的定制，加载路径与上一例子中的路径加载保持一致。

```java
@Bean
public WelcomePageHandlerMapping welcomePageHandlerMapping(ApplicationContext applicationContext, FormattingConversionService mvcConversionService, ResourceUrlProvider mvcResourceUrlProvider) {
    WelcomePageHandlerMapping welcomePageHandlerMapping = new WelcomePageHandlerMapping(new TemplateAvailabilityProviders(applicationContext), applicationContext, this.getWelcomePage(), this.mvcProperties.getStaticPathPattern());
    welcomePageHandlerMapping.setInterceptors(this.getInterceptors(mvcConversionService, mvcResourceUrlProvider));
    return welcomePageHandlerMapping;
}

private Optional<Resource> getWelcomePage() {
    String[] locations = WebMvcAutoConfiguration.getResourceLocations(this.resourceProperties.getStaticLocations());
    return Arrays.stream(locations).map(this::getIndexHtml).filter(this::isReadable).findFirst();
}

// 首页名称
private Resource getIndexHtml(String location) {
    return this.resourceLoader.getResource(location + "index.html");
}
```



### 7.3 Thymeleaf模板引擎

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;开源的模板引擎有很多，包括：JSP、Velocity、Freemarker、Thymeleaf等，SpringBoot 官方推荐使用 Thymeleaf 引擎。模板引擎使用都大同小异，具体使用规则可以参照：https://www.thymeleaf.org/

在 springboot 中 thymeleaf 都在 `classpath: templates/` 下使用，可以通过依赖引入：

```xml
<dependency>
	<groupId>org.thymeleaf</groupId>
    <artifactId>thymeleaf-spring5</artifactId>
</dependency>

<dependency>
	<groupId>org.thymeleaf.extras</groupId>
    <artifactId>thymeleaf-extras-java8time</artifactId>
</dependency>
```



### 7.4 SpringMVC的扩展

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;WebMvcConfigurer 是 重要的配置类接口，该接口内部方法都不是抽象方法，而是空方法，通过该接口可以扩展我们需要的功能，比如我们现在需要向 SpringMVC 中添加自定义的视图解析器，就可以自定义实现，如下：

```java
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.View;
import org.springframework.web.servlet.ViewResolver;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

import java.util.Locale;

@Configuration
public class MyWebMvcConfig implements WebMvcConfigurer {

    @Bean
    public ViewResolver myViewResolver() {
        return new MyViewResolver();
    }

    private static class MyViewResolver implements ViewResolver {
        @Override
        public View resolveViewName(String s, Locale locale) throws Exception {
            return null;
        }
    }
}
```

通过标记该类为配置类并通过 @Bean 向 IOC 中注册，就可以实现自定义的 SpringMVC 功能扩展，同理，如果扩展其他功能只要继续注册即可。

甚至，可以通过 @EnbleWebMvc 接管整个 WebMvc 的控制，但需要主要使用该注解则 springboot 的功能将全部失效。



在实际开发过程中，如果不是单体应用，基本上都已经实现前后端分离，SpringBoot 只负责开发微服务功能并对外提供接口，本节介绍的内容全部都由前端框架控制。



### 7.5 执行异步功能

当后台同步执行耗时任务时，前台请求会出于等待状态，这是无法忍受的，SpringBoot 支持通过@EnableAsync 开始异步任务支持，并在业务类中标记@Async开启异步执行。

1. 创建耗时任务和请求。

```java
@Service
public class AsyncService {

    public void asyncMethod() {
        try {
            TimeUnit.SECONDS.sleep(3);
        } catch (InterruptedException e) {
            e.printStackTrace();
        }
    }
}

@RestController
public class AsyncController {

    @Autowired
    private AsyncService asyncService;

    @GetMapping("/async")
    public String asyncTest() {
        asyncService.asyncMethod();
        return "test";
    }
}

// 此时请求 /async 会长时间等待3秒
```

2. 开启异步支持。

```java
// SpringBoot 主类开启异步支持
@EnableAsync
@SpringBootApplication
public class App {

    public static void main(String[] args) {
        SpringApplication.run(App.class, args);
    }

}

@Service
public class AsyncService {

    @Async
    public void asyncMethod() {
        try {
            TimeUnit.SECONDS.sleep(3);
        } catch (InterruptedException e) {
            e.printStackTrace();
        }
    }
}

// 当再次请求 /async 时，会即使返回接口结果，耗时任务将异步执行
```



### 7.6 执行定时器任务

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;SpringBoot集成了定时器任务，通过@EnableSchdualing开启定时器开关，在定时任务方法上使用@Scheduled执行，同样采用 Cron 表达式定义执行时间。

```java
@EnableScheduling
@SpringBootApplication
public class App {

    public static void main(String[] args) {
        SpringApplication.run(App.class, args);
    }

}

@Service
public class TimerTask {

    // Cron： 秒 分 时 日 月 周
    @Scheduled(cron = "0 * * * * ?")
    public void execute() {
        System.out.println("执行任务");
    }
}
```

