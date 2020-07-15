---
title: Java源码——ConcurrentHashMap（二）
date: 2020-5-25
tags: [源码]
---
{% asset_img image1.jpg HashMap %}

# ConcurrentHashMap（二）
<!--more-->

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Java7中ConcurrentHashMap采取了数据一致性和效率的折中办法——分段锁Segment，但为了进一步提高性能，Java8中完全抛弃了分段锁，采用CAS + synchronized方式解决并发问题。这是一种更加细粒度的加锁方式，直接针对哈希表的槽。

{% asset_img concurrenthashmap8.png concurrenthashmap %}

1. ReservationNode，对占位节点加锁，当执行compute方法和computeIfAbsent方法时使用。
2. TreeBin，并不保存实际红黑树，只是对红黑树所在桶进行读写锁维护，并指向红黑树的引用。
3. ForwardingNode，扩容转发节点，外部对原哈希槽的操作会转发到nextTable上。

**ConcurrentHashMap属性**

```java
// 摘抄部分重要的属性

// 同JDK8的HashMap，设定了树化和回退链表的阈值，唯一不同的是，在进行
// 树化操作时，要求桶数组容量必须大于64
static final int TREEIFY_THRESHOLD = 8;
static final int UNTREEIFY_THRESHOLD = 6;
static final int MIN_TREEIFY_CAPACITY = 64;

// 桶数组，哈希表的具体数据承载结构
transient volatile Node<K,V>[] table;

// 扩容时的哈希表，扩容也是2倍增长且保持2次幂容量
private transient volatile Node<K,V>[] nextTable;

// 初始化和扩容控制
// sizeCtl=-1， 正在进行初始化
// sizeCtl=-n， 有n-1个线程正在扩容
// sizeCtl=0，  默认值，使用默认容量进行初始化
// sizeCtl>0，  扩容需要用到的容量，即阈值
private transient volatile int sizeCtl;

// ForwardingNode节点的哈希值
static final int MOVED     = -1; 

// 红黑树根节点哈希值
static final int TREEBIN   = -2; 

// 数据节点的保存结构，同HashMap
static class Node<K,V> implements Map.Entry<K,V> {
    final int hash;
    final K key;
    volatile V val;
    volatile Node<K,V> next;
}

// 扩容转发节点，当该节点置于桶中，外部对原来哈希表的操作会转移到nextTable上进行
static final class ForwardingNode<K,V> extends Node<K,V> {
    final Node<K,V>[] nextTable;
    Node<K,V> find(int h, Object k) {...}
}

// 预置加锁节点，对桶内的第一个数据进行加锁
static final class ReservationNode<K,V> extends Node<K,V> {
    ReservationNode() {
        super(RESERVED, null, null, null);
    }

    Node<K,V> find(int h, Object k) {
        return null;
    }
}

// 维护对桶内红黑树的读写所，保存红黑树节点的引用
static final class TreeBin<K,V> extends Node<K,V> {
    TreeNode<K,V> root;
    volatile TreeNode<K,V> first;
    volatile Thread waiter;
    volatile int lockState;
    // values for lockState
    static final int WRITER = 1; // set while holding write lock
    static final int WAITER = 2; // set when waiting for write lock
    static final int READER = 4; // increment value for setting read lock
    ...
}

// 红黑树的数据存储节点
static final class TreeNode<K,V> extends Node<K,V> {
    TreeNode<K,V> parent;  // red-black tree links
    TreeNode<K,V> left;
    TreeNode<K,V> right;
    TreeNode<K,V> prev;    // needed to unlink next upon deletion
    boolean red;
    ...
}
```

<font color=red>Java8中显式的取消了加载因此loadFactor，但并没有取消阈值的计算threshold = capacity * loadFactor，而是采用n - (n >>> 2) 的方式代替，构造器同样支持传入自定义加载因子，但只会在初始化容器时使用</font>

**构造器**

```java
public ConcurrentHashMap() {} // 空构造器，初始化放在第一次添加位置

// 自定义容量，对容量向上取2次幂，对sizeCtl赋值
public ConcurrentHashMap(int initialCapacity) {
    if (initialCapacity < 0)
        throw new IllegalArgumentException();
    int cap = ((initialCapacity >= (MAXIMUM_CAPACITY >>> 1)) ?
               MAXIMUM_CAPACITY :
               tableSizeFor(initialCapacity + (initialCapacity >>> 1) + 1));
    this.sizeCtl = cap;
}

```



**put方法**

```java
public V put(K key, V value) {
    return putVal(key, value, false);
}

final V putVal(K key, V value, boolean onlyIfAbsent) {
    if (key == null || value == null) throw new NullPointerException();
    int hash = spread(key.hashCode()); // 哈希函数
    int binCount = 0; // 记录相应链表长度
    for (Node<K,V>[] tab = table;;) {
        Node<K,V> f; int n, i, fh;
        // 空哈希表初始化
        if (tab == null || (n = tab.length) == 0)
            tab = initTable(); // CAS初始化

        // tabAt是落槽操作
        else if ((f = tabAt(tab, i = (n - 1) & hash)) == null) {
            // 如果落槽位置无数据，使用CAS放入新值，如果CAS失败说明产生并发初始化
            if (casTabAt(tab, i, null, new Node<K,V>(hash, key, value, null)))
                break;                   
        }
        // MOVED表示产生数据迁移，那么当前线程帮助进行数据迁移
        else if ((fh = f.hash) == MOVED)
            tab = helpTransfer(tab, f);
        else { // 当前桶不为空，且指向头结点
            V oldVal = null;
            // 对该位置的头结点加锁，进行put操作
            // synchronized已经进行了优化，采取偏向所、轻量锁和重量锁的升级
            synchronized (f) {
                if (tabAt(tab, i) == f) { // 再次确认当前落槽位置没有发生变化
                    if (fh >= 0) { // 头结点的 hash 值大于 0，说明是链表，
                        binCount = 1; // 链表长度计数器
                        // 遍历链表确认是覆盖还是新增，与HashMap同理
                        for (Node<K,V> e = f;; ++binCount) {
                            K ek;
                            if (e.hash == hash &&
                                ((ek = e.key) == key ||
                                 (ek != null && key.equals(ek)))) {
                                oldVal = e.val;
                                if (!onlyIfAbsent)
                                    e.val = value;
                                break;
                            }
                            Node<K,V> pred = e;
                            if ((e = e.next) == null) {
                                pred.next = new Node<K,V>(hash, key,
                                                          value, null);
                                break;
                            }
                        }
                    }
                    // 红黑树
                    else if (f instanceof TreeBin) { 
                        Node<K,V> p;
                        binCount = 2;
                        // 调用红黑树的插值方法插入新节点
                        if ((p = ((TreeBin<K,V>)f).putTreeVal(hash, key,
                                                       value)) != null) {
                            oldVal = p.val;
                            if (!onlyIfAbsent)
                                p.val = value;
                        }
                    }
                }
            }

            if (binCount != 0) {
                // 判断是否需要将链表树化
                // 虽然树化阈值也是8，但与HashMap不同点在于，如果容量小于64则会对哈希表扩容，  						// 如果大于64才进行树化
                if (binCount >= TREEIFY_THRESHOLD)
                    treeifyBin(tab, i);
                if (oldVal != null)
                    return oldVal;
                break;
            }
        }
    }
    addCount(1L, binCount);
    return null;
}
```

> 这里可以看到Java8中采用CAS + synchronized方式保证线程安全，那为什么synchronized在HashTable中效率很低被放弃，但在这里又被重新启用？
>
> 实际上此时JVM对synchronied进行了优化，不在是重量级的互斥锁而变成了可自动升级的锁。我们知道按照锁的效率级别可以分为：偏向锁、轻量级锁和重量级锁，synchronized也正是按照这样的升序级别进行不断升级。
>
> 在JVM字节码中，每个对象都有monitor隐藏参数，该参数是加锁的监视器，当初始化对象锁时monitor=1采用偏向锁，当线程重复进入加锁时会判断，如果当前线程已经存在锁则使用原有锁，这样就保证在低频并发时单线程的执行效率。如果产生并发则将偏向锁升级为轻量级锁，如果并发量增加则会进一步进化为重量级锁。按照Java8中的ConcurrentHashMap采用CAS方式就可以知道设计前提，认为并发并不总是频繁发生的，所以synchronized很少会进入重量级锁。



**哈希函数spread**

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;与Java8中的HashMap哈希函数类似，都是采用key的哈希码自身按照高16位和低16位异或，不同的时此处还进行了常量HASH_BITS的与运算，可以理解为计算更均匀平滑的哈希值，消除负哈希。

```java
static final int HASH_BITS = 0x7fffffff; // usable bits of normal node hash

int hash = spread(key.hashCode());  // put中的方法

static final int spread(int h) {
    return (h ^ (h >>> 16)) & HASH_BITS;
}
```



**初始化initTable**

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;通过CAS来进行初始化，如果被其他线程初始化那么使用yield进行一次自旋，并在下次while循环中退出本次初始化，因为table时volitale的。

```java
private final Node<K,V>[] initTable() {
    Node<K,V>[] tab; int sc;
    while ((tab = table) == null || tab.length == 0) {
        // 被其他线程初始化
        if ((sc = sizeCtl) < 0)
            Thread.yield(); // lost initialization race; just spin
        // CAS操作，sizeCtl = -1，表示抢到了初始化的锁
        else if (U.compareAndSwapInt(this, SIZECTL, sc, -1)) {
            try {
                if ((tab = table) == null || tab.length == 0) {
                    int n = (sc > 0) ? sc : DEFAULT_CAPACITY;
                    // 初始化数组
                    Node<K,V>[] nt = (Node<K,V>[])new Node<?,?>[n];
                    table = tab = nt;
                    sc = n - (n >>> 2); // 阈值，其实等同于n*加载因子0.75
                }
            } finally {
                sizeCtl = sc; // 哈希表容量控制器赋值，如果使用默认容量，该指为12
            }
            break;
        }
    }
    return tab;
}
```

> 显式的取消了加载因子loadFactor，采用 n - (n >>> 2) 作为通过加载因子求阈值的替代。



**扩容tryPresize**

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;HashMap都一样，都是2倍扩容，但是在这里扩容操作稍显复杂，并且伴随着数据迁移的相关操作，整个过程需要sizeCtl参与和控制。

```java
// sizeCtl=-1， 正在进行初始化
// sizeCtl=-n， 有n-1个线程正在扩容
// sizeCtl=0，  默认值，使用默认容量进行初始化
// sizeCtl>0，  扩容需要用到的容量，即阈值
private final void tryPresize(int size) { // size已经是原容量的2倍值
    // 假如size=32，那么c=64
    int c = (size >= (MAXIMUM_CAPACITY >>> 1)) ? MAXIMUM_CAPACITY :
        tableSizeFor(size + (size >>> 1) + 1);
    int sc;
    while ((sc = sizeCtl) >= 0) { 
        Node<K,V>[] tab = table; int n;

        // 同初始化原理
        if (tab == null || (n = tab.length) == 0) {
            n = (sc > c) ? sc : c;
            if (U.compareAndSwapInt(this, SIZECTL, sc, -1)) {
                try {
                    if (table == tab) {
                        Node<K,V>[] nt = (Node<K,V>[])new Node<?,?>[n];
                        table = nt;
                        sc = n - (n >>> 2); 
                    }
                } finally {
                    sizeCtl = sc;
                }
            }
        }
        else if (c <= sc || n >= MAXIMUM_CAPACITY)
            break;
        else if (tab == table) {
            int rs = resizeStamp(n);
            if (sc < 0) { // 有多个线程正在进行扩容
                Node<K,V>[] nt;
                if ((sc >>> RESIZE_STAMP_SHIFT) != rs || sc == rs + 1 ||
                    sc == rs + MAX_RESIZERS || (nt = nextTable) == null ||
                    transferIndex <= 0)
                    break;
                // CAS对sc+1操作并参与数据迁移
                if (U.compareAndSwapInt(this, SIZECTL, sc, sc + 1))
                    transfer(tab, nt);
            }
            // 没有其他线程进行扩容，当前线程进行扩容和数据迁移
            else if (U.compareAndSwapInt(this, SIZECTL, sc,
                                         (rs << RESIZE_STAMP_SHIFT) + 2))
                transfer(tab, null);
        }
    }
}
```



**数据迁移transfer**

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;该方法应该是最难阅读的方法，目的是一个或多个线程协作从旧哈希表将数据迁移到新哈希表中，其原理是：假设原哈希表的容量是x，每个桶做数据迁移需要保持数据一致，可以将一个桶视作一个任务单元，所以有x个迁移任务，按照分治的思想，如果当前有y个线程参与数据迁移，就会把x个迁移任务拆分给每个线程去做。当某个线程完成迁移任务后，会检查是否还有未进行的迁移任务并参与其中。transferIndex用来调度安排线程执行的迁移任务。

```java
private final void transfer(Node<K,V>[] tab, Node<K,V>[] nextTab) {
    int n = tab.length, stride;

    // stride可以理解为拆分任务的分片，与CPU（NCPU参数）有关
    if ((stride = (NCPU > 1) ? (n >>> 3) / NCPU : n) < MIN_TRANSFER_STRIDE)
        stride = MIN_TRANSFER_STRIDE; // subdivide range

    // 如果 nextTab 为 null，先进行一次初始化
    if (nextTab == null) {
        try {
            Node<K,V>[] nt = (Node<K,V>[])new Node<?,?>[n << 1]; // 新的哈希表
            nextTab = nt;
        } catch (Throwable ex) {      
            sizeCtl = Integer.MAX_VALUE;
            return;
        }
        nextTable = nextTab;
        transferIndex = n;
    }

    int nextn = nextTab.length;

    // 如果当前桶正在被线程迁移，则会设置 ForwardingNode 进行加锁
    ForwardingNode<K,V> fwd = new ForwardingNode<K,V>(nextTab);

    boolean advance = true; // 表示可以执行迁移操作
    boolean finishing = false; // 表示完成当前迁移操作

    // i 是位置索引，bound 是边界，注意是从后往前
    for (int i = 0, bound = 0;;) {
        Node<K,V> f; int fh;
        while (advance) {
            int nextIndex, nextBound;
            if (--i >= bound || finishing)
                advance = false;
            // 如果transferIndex小于等于0，说明每个任务都有线程正在执行
            else if ((nextIndex = transferIndex) <= 0) {
                i = -1;
                advance = false;
            }
            else if (U.compareAndSwapInt
                     (this, TRANSFERINDEX, nextIndex,
                      nextBound = (nextIndex > stride ?
                                   nextIndex - stride : 0))) {
                // CAS操作，获取迁移边界
                bound = nextBound;
                i = nextIndex - 1;
                advance = false;
            }
        }
        if (i < 0 || i >= n || i + n >= nextn) {
            int sc;
            // 完成数据迁移
            if (finishing) {
                nextTable = null;
                table = nextTab;
                sizeCtl = (n << 1) - (n >>> 1); // 重新计算 sizeCtl
                return;
            }

            if (U.compareAndSwapInt(this, SIZECTL, sc = sizeCtl, sc - 1)) {
                // 任务结束，方法退出
                if ((sc - 2) != resizeStamp(n) << RESIZE_STAMP_SHIFT)
                    return;
                // 完成迁移任务，设置标志位finishing=true
                finishing = advance = true;
                i = n;
            }
        }
        // 如果位置 i 处是空的，表示没有任何节点，该槽设置ForwardingNode，表示已迁移或正在迁移
        else if ((f = tabAt(tab, i)) == null)
            advance = casTabAt(tab, i, null, fwd);
        else if ((fh = f.hash) == MOVED)
            advance = true; 
        else {
            // 对桶加锁，进行迁移工作
            synchronized (f) {
                if (tabAt(tab, i) == f) { // 头结点的 hash 大于 0，说明是链表
                    Node<K,V> ln, hn;
                    if (fh >= 0) {
                        // 具体迁移方法，原理同JAVA8的HashMap
                        int runBit = fh & n;
                        Node<K,V> lastRun = f;
                        for (Node<K,V> p = f.next; p != null; p = p.next) {
                            int b = p.hash & n;
                            if (b != runBit) {
                                runBit = b;
                                lastRun = p;
                            }
                        }
                        if (runBit == 0) {
                            ln = lastRun;
                            hn = null;
                        }
                        else {
                            hn = lastRun;
                            ln = null;
                        }
                        for (Node<K,V> p = f; p != lastRun; p = p.next) {
                            int ph = p.hash; K pk = p.key; V pv = p.val;
                            if ((ph & n) == 0)
                                ln = new Node<K,V>(ph, pk, pv, ln);
                            else
                                hn = new Node<K,V>(ph, pk, pv, hn);
                        }
                        setTabAt(nextTab, i, ln);
                        setTabAt(nextTab, i + n, hn);
                        setTabAt(tab, i, fwd); // 设置ForwardingNode表示迁移完成
                        // advance 设置为 true，表示该桶迁移完毕
                        advance = true;
                    }
                    else if (f instanceof TreeBin) { // 红黑树的迁移，原理同HashMap和以上
                        TreeBin<K,V> t = (TreeBin<K,V>)f;
                        TreeNode<K,V> lo = null, loTail = null;
                        TreeNode<K,V> hi = null, hiTail = null;
                        int lc = 0, hc = 0;
                        for (Node<K,V> e = t.first; e != null; e = e.next) {
                            int h = e.hash;
                            TreeNode<K,V> p = new TreeNode<K,V>
                                (h, e.key, e.val, null, null);
                            if ((h & n) == 0) {
                                if ((p.prev = loTail) == null)
                                    lo = p;
                                else
                                    loTail.next = p;
                                loTail = p;
                                ++lc;
                            }
                            else {
                                if ((p.prev = hiTail) == null)
                                    hi = p;
                                else
                                    hiTail.next = p;
                                hiTail = p;
                                ++hc;
                            }
                        }
                        ln = (lc <= UNTREEIFY_THRESHOLD) ? untreeify(lo) :
                            (hc != 0) ? new TreeBin<K,V>(lo) : t;
                        hn = (hc <= UNTREEIFY_THRESHOLD) ? untreeify(hi) :
                            (lc != 0) ? new TreeBin<K,V>(hi) : t;

                        setTabAt(nextTab, i, ln);
                        setTabAt(nextTab, i + n, hn);
                        setTabAt(tab, i, fwd);
                        advance = true;
                    }
                }
            }
        }
    }
}
```

数据迁移方法还是比较复杂的，具体的迁移方法与Java8的HashMap相同，困难主要体现在对多个线程参与数据迁移过程的控制，当然，理解了Doug Lea的设计原理，源码阅读也会相对明了一些。