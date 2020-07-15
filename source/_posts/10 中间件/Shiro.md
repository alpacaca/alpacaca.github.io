---
title: Shiro
date: 2020-4-1
tags: [中间件, Shiro]
---
{% asset_img image1.jpg Shiro%}

# Shiro
<!--more-->

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Apache Shiro是一个功能强大且易于使用的Java安全框架，为开发人员提供了一个直观而全面的解决方案，用于身份验证、授权、加密和会话管理。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;实际上，它实现了管理应用程序安全性的所有方面，同时尽可能避免出现问题。它建立在完善的接口驱动设计和面向对象的原则之上，可以在任何你想象得到的地方实现自定义行为。但是，对于所有事情来说，默认情况下都是合理的，这与应用程序安全性是一样的。

## 1 QuickStart

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;该小节通过官方给出的 QuickStart 项目来创建一个简单的应用，并通过分析源码来对 Shiro 形成一个整体印象，具体步骤如下：

1. 创建 maven 工程，导入如下依赖：

``` xml
<dependency>
    <groupId>org.apache.shiro</groupId>
    <artifactId>shiro-core</artifactId>
    <version>1.5.3</version>
</dependency>

<!-- configure logging -->
<dependency>
    <groupId>org.slf4j</groupId>
    <artifactId>jcl-over-slf4j</artifactId>
    <version>1.7.30</version>
</dependency>
<dependency>
    <groupId>org.slf4j</groupId>
    <artifactId>slf4j-simple</artifactId>
    <version>1.7.30</version>
</dependency>
<dependency>
    <groupId>commons-logging</groupId>
    <artifactId>commons-logging</artifactId>
    <version>1.2</version>
</dependency>
```



2. 在 resources 下创建日志文件 log4j.properties 和 shiro 配置文件 `shiro.ini`。

```ini
# [shiro.ini]
# -----------------------------------------------------------------------------
# Users and their assigned roles
#
# Each line conforms to the format defined in the
# org.apache.shiro.realm.text.TextConfigurationRealm#setUserDefinitions JavaDoc
# -----------------------------------------------------------------------------
[users]
# user 'root' with password 'secret' and the 'admin' role
root = secret, admin
# user 'guest' with the password 'guest' and the 'guest' role
guest = guest, guest
# user 'presidentskroob' with password '12345' ("That's the same combination on
# my luggage!!!" ;)), and role 'president'
presidentskroob = 12345, president
# user 'darkhelmet' with password 'ludicrousspeed' and roles 'darklord' and 'schwartz'
darkhelmet = ludicrousspeed, darklord, schwartz
# user 'lonestarr' with password 'vespa' and roles 'goodguy' and 'schwartz'
lonestarr = vespa, goodguy, schwartz

# -----------------------------------------------------------------------------
# Roles with assigned permissions
#
# Each line conforms to the format defined in the
# org.apache.shiro.realm.text.TextConfigurationRealm#setRoleDefinitions JavaDoc
# -----------------------------------------------------------------------------
[roles]
# 'admin' role has all permissions, indicated by the wildcard '*'
admin = *
# The 'schwartz' role can do anything (*) with any lightsaber:
schwartz = lightsaber:*
# The 'goodguy' role is allowed to 'drive' (action) the winnebago (type) with
# license plate 'eagle5' (instance specific id)
goodguy = winnebago:drive:eagle5
```

```properties
# [log4j.properties]
log4j.rootLogger=INFO, stdout

log4j.appender.stdout=org.apache.log4j.ConsoleAppender
log4j.appender.stdout.layout=org.apache.log4j.PatternLayout
log4j.appender.stdout.layout.ConversionPattern=%d %p [%c] - %m %n

# General Apache libraries
log4j.logger.org.apache=WARN

# Spring
log4j.logger.org.springframework=WARN

# Default Shiro logging
log4j.logger.org.apache.shiro=INFO

# Disable verbose logging
log4j.logger.org.apache.shiro.util.ThreadContext=WARN
log4j.logger.org.apache.shiro.cache.ehcache.EhCache=WARN
```



3. 创建一个测试类 QuickStart，通过main函数调用。

```java
public class Quickstart {

    private static final transient Logger log = LoggerFactory.getLogger(Quickstart.class);


    public static void main(String[] args) {
        // 通过加载 shiro.ini 创建 Shiro SecurityManager对象
        Factory<SecurityManager> factory = new IniSecurityManagerFactory("classpath:shiro.ini");
        SecurityManager securityManager = factory.getInstance();
        SecurityUtils.setSecurityManager(securityManager);

        // shiro 环境就设置好了，接下来看看能做些什么
        // 1 获得当前执行用户
        Subject currentUser = SecurityUtils.getSubject();

        // 2 可以使用 shiro Session 对象做一些事情，比如赋值和获取值
        Session session = currentUser.getSession();
        session.setAttribute("someKey", "aValue");
        String value = (String) session.getAttribute("someKey");
        if (value.equals("aValue")) {
            log.info("Retrieved the correct value! [" + value + "]");
        }

        // 3 对当前用户授权
        if (!currentUser.isAuthenticated()) {
            UsernamePasswordToken token = new UsernamePasswordToken("lonestarr", "vespa");
            token.setRememberMe(true);
            try {
                currentUser.login(token);
            } catch (UnknownAccountException uae) {
                log.info("There is no user with username of " + token.getPrincipal());
            } catch (IncorrectCredentialsException ice) {
                log.info("Password for account " + token.getPrincipal() + " was incorrect!");
            } catch (LockedAccountException lae) {
                log.info("The account for username " + token.getPrincipal() + " is locked.  " + "Please contact your administrator to unlock it.");
            } catch (AuthenticationException ae) {
                //unexpected condition?  error?
            }
        }

        // 打印
        log.info("User [" + currentUser.getPrincipal() + "] logged in successfully.");

        // 测试当前用户的角色
        if (currentUser.hasRole("schwartz")) {
            log.info("May the Schwartz be with you!");
        } else {
            log.info("Hello, mere mortal.");
        }

        // 测试当前用户的权限
        if (currentUser.isPermitted("lightsaber:wield")) {
            log.info("You may use a lightsaber ring.  Use it wisely.");
        } else {
            log.info("Sorry, lightsaber rings are for schwartz masters only.");
        }

        if (currentUser.isPermitted("winnebago:drive:eagle5")) {
            log.info("You are permitted to 'drive' the winnebago with license plate (id) 'eagle5'.  " + "Here are the keys - have fun!");
        } else {
            log.info("Sorry, you aren't allowed to drive the 'eagle5' winnebago!");
        }

        // 退出
        currentUser.logout();
        System.exit(0);
    }
}
```

简单来说，通过 shiro.ini 加载创建了 SecurityManager 对象，通过该对象可以获取当前的执行用户 Subject 对象，当前用户的管理内容包括：会话管理、授权和验证。在授权阶段通过用户名和密码就可以创建一个令牌 token，之后可以验证当前用户的权限信息。



## 2 Shiro 概述

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Shiro 所谓的“应用程序安全性的四个基石”为目标-身份验证，授权，会话管理和密码术：

- **身份验证：**有时称为“登录”，这是证明用户就是他们所说的身份的行为。
- **授权：**访问控制的过程，即确定“谁”有权访问“什么”。
- **会话管理：**即使在非Web或EJB应用程序中，也管理用户特定的会话。
- **密码：**使用密码算法保持数据安全，同时仍易于使用。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;在不同的应用程序环境中，还具有其他功能来支持和加强这些问题，尤其是：

- Web支持：Shiro的Web支持API可帮助轻松保护Web应用程序。
- 缓存：缓存是Apache Shiro API的第一层公民，可确保安全操作保持快速和高效。
- 并发性：Apache Shiro的并发功能支持多线程应用程序。
- 测试：测试支持可帮助您编写单元测试和集成测试，并确保您的代码将按预期进行保护。



{% asset_img 1.png Shiro%}



&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Shiro 包含三个核心组件：SecurityManager、Subject、Realms。

- SecurityManager：它是 Shiro 框架的核心管理器，属于门面对象，提供安全管理的各种服务。
- Subject：“当前操作用户”，它既可以指当前操作用户，也可以指正在执行的第三方进程等。
- Realme：它封装了数据源，向 Shiro 提供相关数据，也就是说，Shiro 会从 Realme 中查找用户权限信息。

{% asset_img 2.png Shiro%}



## 3 SecurityManager

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;SecurityManager 是 Shiro 体系结构的核心，该对象协调其内部安全组件，这些内部安全组件一起形成对象图。一旦为应用程序配置了SecurityManager及其内部对象图，通常就不理会它，几乎所有的时间都花在SubjectAPI 上。在Shiro的默认SecurityManager实现中，安全操作管理包含：

- Authentication，认证
- Authorization，授权
- Session Management，会话管理
- Cache Management，缓存管理
- [Realm](http://shiro.apache.org/realm.html) coordination，领域协调
- Event propagation，时间传播

```java
public interface SecurityManager extends Authenticator, Authorizer, SessionManager {
    
    Subject login(Subject subject, AuthenticationToken authenticationToken) throws AuthenticationException;

    void logout(Subject subject);

    Subject createSubject(SubjectContext context);

}
```

其实现类包括 `AuthenticatingSecurityManager、AuthorizingSecurityManager、CachingSecurityManager、DefaultSecurityManager、RealmSecurityManager、SessionsSecurityManager`，下面以 DefaultSecurityManager 为例进行源码分析:

```java
public class DefaultSecurityManager extends SessionsSecurityManager {
    // 通过内部集合的方式管理素有的授权和验证操作
    private Collection<Realm> realms;
    
    // 创建所属 Realme的管理器
    public DefaultSecurityManager(Realm singleRealm) {
        this();
        setRealm(singleRealm);
    }
    
    /*
     *登录方法
     *如果登录成功将创建 Subject 实例来替代验证账户的id，并绑定到应用中
     */
    public Subject login(Subject subject, AuthenticationToken token) throws AuthenticationException {
        AuthenticationInfo info;
        // 验证失败将以异常的形式抛出
        try {
            info = authenticate(token);
        } catch (AuthenticationException ae) {
            try {
                onFailedLogin(token, ae, subject);
            } catch (Exception e) {
                if (log.isInfoEnabled()) {
                    log.info("onFailedLogin method threw an " +
                            "exception.  Logging and propagating original AuthenticationException.", e);
                }
            }
            throw ae; 
        }

        // 验证成功，创建 Subject 实例对象
        Subject loggedIn = createSubject(token, info, subject);
        onSuccessfulLogin(token, info, loggedIn);
        return loggedIn;
    }
    
    
    /**
     * 注销方法
     * 一旦注销成功将删除本次 Subject 对象
     */
    public void logout(Subject subject) {
        if (subject == null) {
            throw new IllegalArgumentException("Subject method argument cannot be null.");
        }
        beforeLogout(subject);
        PrincipalCollection principals = subject.getPrincipals();
        if (principals != null && !principals.isEmpty()) {
            if (log.isDebugEnabled()) {
                log.debug("Logging out subject with primary principal {}", principals.getPrimaryPrincipal());
            }
            Authenticator authc = getAuthenticator();
            if (authc instanceof LogoutAware) {
                ((LogoutAware) authc).onLogout(principals); // 先从认证器中删除principals
            }
        }

        try {
            delete(subject); // 删除 subject 对象
        } catch (Exception e) {
            if (log.isDebugEnabled()) {
                String msg = "Unable to cleanly unbind Subject.  Ignoring (logging out).";
                log.debug(msg, e);
            }
        } finally {
            try {
                stopSession(subject); // 关闭session
            } catch (Exception e) {
                if (log.isDebugEnabled()) {
                    String msg = "Unable to cleanly stop Session for Subject [" + subject.getPrincipal() + "] " +
                            "Ignoring (logging out).";
                    log.debug(msg, e);
                }
            }
        }
    }
}

//

public abstract class RealmSecurityManager extends CachingSecurityManager {

    /// 通过内部集合的方式管理素有的授权和验证操作
    private Collection<Realm> realms;
    
    public void setRealms(Collection<Realm> realms) {
        if (realms == null) {
            throw new IllegalArgumentException("Realms collection argument cannot be null.");
        }
        if (realms.isEmpty()) {
            throw new IllegalArgumentException("Realms collection argument cannot be empty.");
        }
        this.realms = realms;
        afterRealmsSet();
    }
}
```



## 4 Subject

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Subject 称为当前“用户”，这个用户可以使执行用户，也可以是任意第三方进程，通过Subject可以获得当前用户和 Session。

```java
Subject subject = SecurityUtils.getSubject(); 
Session session = subject.getSession();
session.setAttribute( "someKey", "aValue" );
```

首先看一下 getSubject() 源码，作为静态类获得当前用户，Shiro 通过线程与“用户”绑定，通过线程上下文就可以获得当前线程对应的用户。

```java
public static Subject getSubject() {
    // 从线程上下文获得
    Subject subject = ThreadContext.getSubject();
    // 如果用户为空，则创建用户并绑定到ThreadContext中
    if (subject == null) {
        subject = (new Subject.Builder()).buildSubject();
        ThreadContext.bind(subject);
    }
    return subject;
}

public abstract class ThreadContext {
    // 线程上下文使用 ThreadLocal 绑定当前线程和用户
    private static final ThreadLocal<Map<Object, Object>> resources = new InheritableThreadLocalMap<Map<Object, Object>>();
}
```



在 Session 中，Shiro 默认使用 DelegatingSession，它的方法名与 HttpServletSession 保持一致，当我们开启 Web 服务后，Shiro 的 Session 会自动实现 HttpServletSession，该对象也是 Shiro 中封装的。

```java
public class HttpServletSession implements Session {
    // 通过组合的方式，将HttpSession封装在对象内，这样在前端使用时也可以识别
    private HttpSession httpSession = null;
}
```



Subject 最重要的功能就是判断当前用户的权限和角色，这样就可以在 Realme 中进行相应的 授权和验证工作。

```java
// 登录
try {
    subject.login(token);
    // 没有抛异常则登录成功
} catch ( UnknownAccountException uae ) {
    System.out.println("用户名不存在");
} catch ( IncorrectCredentialsException ice ) {
    System.out.println("密码错误");
} catch ( LockedAccountException lae ) {
    System.out.println("用户被锁定，不能登录");
} catch ( AuthenticationException ae ) {
    System.out.println("严重的错误");
}

// 注销
subject.logout();

// 获得当前用户
String currentUser = subject.getPrincipal().toString();
// 判断用户是否是拥有角色
boolean isRole = subject.hasRole( "admin" );
// 是否拥有权限
boolean isPer = subject.isPermitted("user:add");


```





## 5 Realme

（保留）

**多Realme的使用**



## 6 SpringBoot 集成 Shiro 完整示例

1. 导入 shiro 依赖:

```xml
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-web</artifactId>
</dependency>

<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-configuration-processor</artifactId>
    <optional>true</optional>
</dependency>

<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-jdbc</artifactId>
</dependency>

<dependency>
    <groupId>org.apache.shiro</groupId>
    <artifactId>shiro-spring</artifactId>
    <version>1.4.1</version>
</dependency>

<dependency>
    <groupId>mysql</groupId>
    <artifactId>mysql-connector-java</artifactId>
    <scope>runtime</scope>
</dependency>

<dependency>
    <groupId>com.alibaba</groupId>
    <artifactId>druid</artifactId>
    <version>1.1.23</version>
</dependency>

<dependency>
    <groupId>org.mybatis.spring.boot</groupId>
    <artifactId>mybatis-spring-boot-starter</artifactId>
    <version>2.1.1</version>
</dependency>

<dependency>
    <groupId>org.projectlombok</groupId>
    <artifactId>lombok</artifactId>
    <optional>true</optional>
</dependency>

<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-thymeleaf</artifactId>
</dependency>

<dependency>
    <groupId>log4j</groupId>
    <artifactId>log4j</artifactId>
    <version>1.2.17</version>
</dependency>
```



2. 整合mybatis的代码，修改数据库，添加 password 字段和  permission 字段，分辨用于管理用户密码和权限。

{% asset_img 6.png shiro%}



同时修改 User 类、UserMapper接口和 UserMapper.xml。

```java
@NoArgsConstructor
@AllArgsConstructor
@ToString
public class User {

    @Getter @Setter
    private Integer id;

    @Getter @Setter
    private String name;

    @Getter @Setter
    private String password;

    @Getter @Setter
    private String permission;
}
```

```xml
@Mapper
@Repository
public interface UserMapper {

    List<User> getUsers();

    User getUserByID(Integer id);

    User getUser(String username);
}

```

```xml
<?xml version="1.0" encoding="UTF-8" ?>
<!DOCTYPE mapper PUBLIC "-//mybatis.org//DTD Mapper 3.0//EN" "http://mybatis.org/dtd/mybatis-3-mapper.dtd">
<mapper namespace="me.zhy.integrate.entity.mapper.UserMapper">
    <select id="getUsers" resultType="User">
       select * from tb_user;
    </select>

    <select id="getUserByID" resultType="User" parameterType="int">
       select * from tb_user where id = #{id};
    </select>

    <select id="getUser" resultType="User" parameterType="String">
       select * from tb_user where `name` = #{username};
    </select>
</mapper>
```



创建服务类，用于从数据库获取真实数据

```java
@Service
public class UserService {

    private UserMapper userMapper;

    public User getUser(String username) {
        return userMapper.getUser(username);
    }

    @Autowired
    public void setUserMapper(UserMapper userMapper) {
        this.userMapper = userMapper;
    }
}
```



3. 创建自定义 Realme，用于实现授权和验证的具体实现，数据部分采用数据库中的真实 tb_user 数据：

```java
public class UserShiroRealme extends AuthorizingRealm {

    private UserService userService;

    // 授权
    @Override
    protected AuthorizationInfo doGetAuthorizationInfo(PrincipalCollection principalCollection) {
        SimpleAuthorizationInfo info = new SimpleAuthorizationInfo();
        Subject subject = SecurityUtils.getSubject();  // 获得当前用户
        User currentUser = (User) subject.getPrincipal();
        info.addStringPermission(currentUser.getPermission()); // 添加当前用户的权限
        return info;
    }

    // 验证
    @Override
    protected AuthenticationInfo doGetAuthenticationInfo(AuthenticationToken authenticationToken)
            throws AuthenticationException {
        // 获得 controller 封装的前台用户名和密码 token
        UsernamePasswordToken token = (UsernamePasswordToken) authenticationToken;
        String username = token.getUsername();
        User user = userService.getUser(username); // 从数据库读取数据
        if (Objects.isNull(user)) {
            // 对象为空，验证失败
            return null;
        }
        String password = user.getPassword();
        // user 将在授权中继续使用， password 将被 shiro 自行密文验证
        return new SimpleAuthenticationInfo(user, password, "");
    }

    @Autowired
    public void setUserService(UserService userService) {
        this.userService = userService;
    }
}
```



4. 创建 Shiro 配置类，向 IOC 容器注册，包含核心组件 Realme、SecurityManager 和 过滤器链 ShiroFilterFactoryBean，其中 SecurityManager 使用与 Web 相关的 DefaultWebSecurityManager：

```java
package me.zhy.integrate.config.shiro;

import me.zhy.integrate.entity.domain.User;
import me.zhy.integrate.service.UserService;
import org.apache.shiro.SecurityUtils;
import org.apache.shiro.authc.*;
import org.apache.shiro.authz.AuthorizationInfo;
import org.apache.shiro.authz.SimpleAuthorizationInfo;
import org.apache.shiro.realm.AuthorizingRealm;
import org.apache.shiro.session.Session;
import org.apache.shiro.subject.PrincipalCollection;
import org.apache.shiro.subject.Subject;
import org.springframework.beans.factory.annotation.Autowired;

import java.util.Objects;

public class UserShiroRealme extends AuthorizingRealm {

    private UserService userService;

    // 授权
    @Override
    protected AuthorizationInfo doGetAuthorizationInfo(PrincipalCollection principalCollection) {
        SimpleAuthorizationInfo info = new SimpleAuthorizationInfo();
        Subject subject = SecurityUtils.getSubject();  // 获得当前用户
        User currentUser = (User) subject.getPrincipal();
        info.addStringPermission(currentUser.getPermission()); // 添加当前用户的权限
        return info;
    }

    // 验证
    @Override
    protected AuthenticationInfo doGetAuthenticationInfo(AuthenticationToken authenticationToken)
            throws AuthenticationException {
        // 获得 controller 封装的前台用户名和密码 token
        UsernamePasswordToken token = (UsernamePasswordToken) authenticationToken;
        String username = token.getUsername();
        User user = userService.getUser(username); // 从数据库读取数据
        if (Objects.isNull(user)) {
            // 对象为空，验证失败
            return null;
        }
        // 验证成功，将对象放入shiro.Session中
        Subject subject = SecurityUtils.getSubject();
        Session session = subject.getSession();
        session.setAttribute("user", user);
        
        String password = user.getPassword();
        // user 将在授权中继续使用， password 将被 shiro 自行密文验证
        return new SimpleAuthenticationInfo(user, password, "");
    }

    @Autowired
    public void setUserService(UserService userService) {
        this.userService = userService;
    }
}

```

在 step 3 中过滤器链通过 Map<String, String> 方式设置，其中 `key表示拦截的 url 路径，value表示过滤器`，Shiro 在 DefaultFilter 枚举类中提供了多种内置过滤器，这些组件分为两类：认证过滤器和授权过滤器，在文档中介绍如下：



*认证过滤器：*

- anon ：org.apache.shiro.web.filter.authc.AnonymousFilter，*可以匿名使用*
- authc ：org.apache.shiro.web.filter.authc.FormAuthenticationFilter，*需要认证(登录)才能使用*
- authcBasic ：org.apache.shiro.web.filter.authc.BasicHttpAuthenticationFilter，*httpBasic认证*
- user ：org.apache.shiro.web.filter.authz.UserFilter，*示必须存在用户，当登入时不做检查*



*授权过滤器：*

- ssl ：org.apache.shiro.web.filter.authz.SslFilter，*https请求使用*

- port ：org.apache.shiro.web.filter.authz.PortFilter，*参数绑定端口号使用*

- rest ：org.apache.shiro.web.filter.authz.HttpMethodPermissionFilter，*参数绑定rest行为使用，如get*

- perms ：org.apache.shiro.web.filter.authz.PermissionAuthorizationFilter，*权限类别，包含多个参数*

- roles ：org.apache.shiro.web.filter.authz.RolesAuthorizationFilter，*角色类别，包含多个参数*

  

5. 启动 SpringBoot 验证，zhangsan 用户具有 `user:*` 权限可以全部访问；lisi 用户具有 `user:page1` 权限，只能访问 page1 ，page2将提示授权失败；wangwu 用户同理。 