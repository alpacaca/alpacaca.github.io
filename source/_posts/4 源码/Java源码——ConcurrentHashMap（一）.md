---
title: Java源码——ConcurrentHashMap（一）
date: 2020-5-20
tags: [源码]
---
{% asset_img image1.jpg HashMap %}

# ConcurrentHashMap（一）
<!--more-->

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;在并发编程领域，ConcurrentHashMap是最推崇使用的哈希式集合类型。JDK8对它进行了脱胎换骨的改造，大量运用了Lock-Free技术，从而减轻因锁的竞争导致的性能问题，该类涵盖了CAS、锁、volatile、链表、红黑树等知识点，是从官方学习Java并发编程的绝佳案例。

> Lock-Free：是无锁编程(Non-Blocking Sync)的实现，对于共享数据不使用锁来控制并发访问（互斥锁等排它锁类型），而是多线程并行访问，旨在避免使用Lock带来的线程阻塞等性能问题，虽然无法代替Lock。

> CAS（Compare And Swap）：是乐观锁的实现，应用于轻微冲突的并发场景，因为CAS在进行自旋操作时占用CPU较多，所以不适合高并发场景。在JUC的atomic包下大量用到了CAS操作，保证变量的原子性。它的原理是，首先获得值的内存地址、预期值和新值，每个线程在获取并更新的过程中先访问内存地址的预期值比较（Compare）是否一致，如果一致则更新为新值（Swap）；如果不一致，先对预期值轮询操作，比较之后达到预期值再更新新值或者退出。CAS需要避免发生ABA问题，可以通过版本号来增加比较条件进行解决。
>
> 经典的CAS用法来自于AtomicInteger的自增操作方法，如下：

```java
public final int getAndIncrement() {
    for(;;) {
        int current = get(); // 预期值
        int next = current + 1; // 新值
        if (compareAndSet(current, next)) { // 自旋
            return current;
        }
    }
}

// unsafe来自native方法，支持直接调用硬件的原子性能力。
public final boolean compareAndSet(int expect, int update) {
    return unsafe.compareAndSwapInt(this, valueOffset, expect, update);
}
```



**ConcurrentHashMap的发展**

1. 我们知道HashTable是线程安全的字典集合Dictionary，但底层实现使用了性能极差的全互斥方式，所以已经被淘汰。

2. HashMap是非线程安全的Map集合，容易产生并发问题，特别是死链问题。

3. Collections.synchronizedMap(Map<K,V> m)方法是集合工具类对普通Map的同步代理类，原理是使用排它锁mutex来锁定对象。

4. JDK8以前的ConcurrentHashMap采用分段式锁设计，旨在平衡性能和线程安全，内部采用重入锁ReentrantLock进行并发控制，将每个HashEntry进行加锁管理。

5. JDK8之后的ConcurrentHashMap采用Lock-Free理念，取消了分段式锁，采用CAS和其他优化设计提高了并发能力并降低了冲突概率。

   

## 1 HashTable的线程安全

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;HashTable继承自Dictionary类，与HashMap结构大致相同，几个关键的不同点：1. HashTable的哈希函数使用key的哈希码，所以key不允许为null，否则会产生NPE；2. 落槽操作采用哈希表容量取余来完成，效率低，但不会强制要求哈希表容量是2次幂；3. 扩容都是2倍；4. HashTable是线程安全的，它采用重量级的synchronized对方法加锁，效率极低。

{% asset_img hashtable.png HashTable %}

如上图，当线程1调用put方法向1号槽插入数据时会获得整个哈希表的锁，此时线程2同时调用put方法企图向2号槽插入数据就会被阻塞，直到线程1释放锁。很明显，并发put时，如果不是同一个槽位是可以不用对哈希表整体加锁的，效率极低。

```java
// HashTable内都是全互斥锁
public synchronized V put(K key, V value)
public synchronized V get(Object key)
public synchronized boolean contains(Object k)
public synchronized boolean isEmpty()
public synchronized V remove(Object key)
```

不同于在HashMap中已经介绍的**fail-fast机制**同步时如果数据不一致会直接抛出ConcurrentModificationException异常，HashTable采用**fail-safe机制**，其原理是先获得当前哈希表的副本，并对副本进行迭代，虽然不会受到同步修改的影响，但不能保证迭代的数据是最新的。



## 2 Collections.synchronizedMap的线程安全

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Collections提供了多个支持对普通集合同步化的代理类，包括List、Set、Map等，针对不同类型都实现了对应的内部代理类。

```java
static class SynchronizedCollection<E> implements Collection<E>, Serializable {...}

static class SynchronizedSet<E> extends SynchronizedCollection<E> implements Set<E> {...}

static class SynchronizedSortedSet<E> extends SynchronizedSet<E> implements SortedSet<E>{...}

static class SynchronizedList<E> extends SynchronizedCollection<E> implements List<E> {...}

static class SynchronizedRandomAccessList<E> extends SynchronizedList<E> implements RandomAccess {...}

private static class SynchronizedMap<K,V> implements Map<K,V>, Serializable {...}
    
static class SynchronizedSortedMap<K,V> extends SynchronizedMap<K,V> implements SortedMap<K,V> {...}
```

其主要实现是采用互斥锁mutex对对象加锁，在锁级别上与HashTable是一致的，之所以Collections会提供这样重量级的锁是为了保证如果业务涉及高度的数据安全性且性能要求不严苛的场景使用，稍后介绍的ConcurrentHashMap之所以采用CAS，前提是认为并发并不总是存在的。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;内部类提供了两个构造器，默认和指定互斥锁对象，默认情况下互斥锁为当前对象this。

```java
SynchronizedMap(Map<K,V> m) {
    if (m==null)
        throw new NullPointerException();
    this.m = m;
    mutex = this;
}

SynchronizedMap(Map<K,V> m, Object mutex) {
    this.m = m;
    this.mutex = mutex;
}
```



实际调用方法采用指定集合对象的自身方法。

```java
public int size() {
    synchronized (mutex) {return m.size();}
}
public boolean isEmpty() {
    synchronized (mutex) {return m.isEmpty();}
}
public boolean containsKey(Object key) {
    synchronized (mutex) {return m.containsKey(key);}
}
public boolean containsValue(Object value) {
    synchronized (mutex) {return m.containsValue(value);}
}
public V get(Object key) {
    synchronized (mutex) {return m.get(key);}
}

public V put(K key, V value) {
    synchronized (mutex) {return m.put(key, value);}
}
public V remove(Object key) {
    synchronized (mutex) {return m.remove(key);}
}
public void putAll(Map<? extends K, ? extends V> map) {
    synchronized (mutex) {m.putAll(map);}
}
public void clear() {
    synchronized (mutex) {m.clear();}
}
```



## 3. Java7 ConcurrentHashMap的线程安全

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Java7中的ConcurrentHashMap使用了分段锁机制，内部类Segment是实现分段锁的对象，在集合初始化时会先初始化Segment数组，其数组容量与并发级别（concurrency level，或称为并发数）有关，默认并发级别为16与默认容量一致，也就是说默认支持16个线程的并发，默认级别可以通过构造器传入，但适中保持2次幂的值，这时为了使Segment锁可以均匀管理不同的集合，与HashMap落槽操作一样，使用并发级别减1按位与操作来定位分段锁。**分段锁容量初始化后将不在扩容，而分段锁管理的HashMap可以继续扩容**。逻辑结构如下图所示：

{% asset_img concurrenthashmap7.png concurrenthashmap %}

```java
// 主要的构造器实现
// concurrencyLevel为并发级别，可手动传入，但会进行2次幂处理
public ConcurrentHashMap(int initialCapacity,float loadFactor, int concurrencyLevel) {
    if (!(loadFactor > 0) || initialCapacity < 0 || concurrencyLevel <= 0)
        throw new IllegalArgumentException();
    if (concurrencyLevel > MAX_SEGMENTS)
        concurrencyLevel = MAX_SEGMENTS;

    int sshift = 0;
    int ssize = 1;
    // 使用ssize计算分段锁的个数，即2次幂处理
    while (ssize < concurrencyLevel) {
        ++sshift;
        ssize <<= 1;
    }

    // 假设使用默认值concurrencyLevel=ssize=16，sshift=4
    // segmentShift=28
    // segmentMask=15
    this.segmentShift = 32 - sshift;
    this.segmentMask = ssize - 1;

    // initialCapacity是哈希表初始容量
    if (initialCapacity > MAXIMUM_CAPACITY)
        initialCapacity = MAXIMUM_CAPACITY;

    // 根据 initialCapacity 设置Segment可以管理多少个哈希表
    // 假设initialCapacity=16，那么每个 Segment 可以管理1个哈希表，如果initialCapacity=32则可以管理2个
    int c = initialCapacity / ssize;
    if (c * ssize < initialCapacity)
        ++c;
    int cap = MIN_SEGMENT_TABLE_CAPACITY; 
    while (cap < c)
        cap <<= 1;

    // 创建 Segment 数组ss
    Segment<K,V> s0 =
        new Segment<K,V>(loadFactor, (int)(cap * loadFactor),
                         (HashEntry<K,V>[])new HashEntry[cap]);
    Segment<K,V>[] ss = (Segment<K,V>[])new Segment[ssize];
    // 往数组写入s0
    UNSAFE.putOrderedObject(ss, SBASE, s0);
    this.segments = ss;
}
```

> UNSAFE是直接通过java api调用底层CAS能力，只有是bootstrap类加载器加载的类才可以调用UNSAFE，否则只能通过反射来调用。

假设我们全部使用默认值来完成了容器的初始化，此时关键参数如下： 

- Segment数组长度为16且不可扩容
- segmentShift=32-4=28， segmentMask=16-1=15。
- Segment数组只初始化了Segment[0]元素，其他元素还是null。



**put操作**

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;分两部分，第一部分首先在数组中定位Segment，确认使用的分段锁对象。

```java
public V put(K key, V value) {
    Segment<K,V> s;
    if (value == null)
        throw new NullPointerException();
    // 1. 计算 key 的 hash 值
    int hash = hash(key);
    // 2. 类比落槽操作，通过hash无符号右移与掩码按位与，找到Segement数组j位置元素
    int j = (hash >>> segmentShift) & segmentMask;
    // ensureSegment(j) 对 segment[j] 进行初始化
    if ((s = (Segment<K,V>)UNSAFE.getObject         
         (segments, (j << SSHIFT) + SBASE)) == null) 
        s = ensureSegment(j);
    // 3. 插入新值到 槽 s 中
    return s.put(key, hash, value, false);
}
```

第二部分，再确定了分段锁对象后，对分段对象加独占锁，再在其中进行哈希表的put操作，类似与HashMap。

```java
final V put(K key, int hash, V value, boolean onlyIfAbsent) {
    // 4.先获取 segment 的独占锁
    HashEntry<K,V> node = tryLock() ? null :
        scanAndLockForPut(key, hash, value);
    V oldValue;
    try {
        // 该 segment 管理的哈希表
        HashEntry<K,V>[] tab = table;
        // 5.落槽并使用头插法插入数据
        int index = (tab.length - 1) & hash;
        HashEntry<K,V> first = entryAt(tab, index);

        // 同HashMap，检索桶内链表
        for (HashEntry<K,V> e = first;;) {
            if (e != null) {
                K k;
                if ((k = e.key) == key ||
                    (e.hash == hash && key.equals(k))) {
                    oldValue = e.value;
                    if (!onlyIfAbsent) {
                        e.value = value;
                        ++modCount;
                    }
                    break;
                }
                e = e.next;
            }
            else {
                // 如果不为 null，那就直接将它设置为链表表头；如果是null，初始化并设置为链表表头。
                if (node != null)
                    node.setNext(first);
                else
                    node = new HashEntry<K,V>(hash, key, value, first);

                int c = count + 1;
                // 如果超过了该 segment 的阈值， segment的哈希表需要扩容
                if (c > threshold && tab.length < MAXIMUM_CAPACITY)
                    rehash(node); 
                else
                    // 没有达到阈值，将 node 放到数组 tab 的 index 位置，
                    setEntryAt(tab, index, node);
                ++modCount;
                count = c;
                oldValue = null;
                break;
            }
        }
    } finally {
        // 操作完毕，释放锁
        unlock();
    }
    return oldValue;
}
```



**初始化ensureSegment方法**

```java
private Segment<K,V> ensureSegment(int k) {
    final Segment<K,V>[] ss = this.segments;
    long u = (k << SSHIFT) + SBASE; 
    Segment<K,V> seg;
    if ((seg = (Segment<K,V>)UNSAFE.getObjectVolatile(ss, u)) == null) {
        // 使用已初始化的 segment[0] 长度来初始化segment[k]
        Segment<K,V> proto = ss[0];
        int cap = proto.table.length;
        float lf = proto.loadFactor;
        int threshold = (int)(cap * lf);

        // 初始化 segment[k] 管理的哈希表
        HashEntry<K,V>[] tab = (HashEntry<K,V>[])new HashEntry[cap];
        // 检查该Segment是否被其他线程初始化
        if ((seg = (Segment<K,V>)UNSAFE.getObjectVolatile(ss, u))
            == null) { 

            Segment<K,V> s = new Segment<K,V>(lf, threshold, tab);
            // 使用 CAS，当前线程成功设值或其他线程成功设值后，退出
            while ((seg = (Segment<K,V>)UNSAFE.getObjectVolatile(ss, u))
                   == null) {
                if (UNSAFE.compareAndSwapObject(ss, u, null, seg = s))
                    break;
            }
        }
    }
    return seg;
}
```



**加锁scanAndLockForPut**

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**采用ReentrantLock可重入锁来显式的对Segment加锁**。

```java
private HashEntry<K,V> scanAndLockForPut(K key, int hash, V value) {
    HashEntry<K,V> first = entryForHash(this, hash);
    HashEntry<K,V> e = first;
    HashEntry<K,V> node = null;
    int retries = -1; 

    // 循环获取锁，ReentrantLock的tryLock
    while (!tryLock()) {
        HashEntry<K,V> f; 
        if (retries < 0) {
            if (e == null) {
                if (node == null) 
                    // 这里可能是因为 tryLock() 失败，所以该槽存在并发，不一定是该位置
                    node = new HashEntry<K,V>(hash, key, value, null);
                retries = 0;
            }
            else if (key.equals(e.key))
                retries = 0;
            else
                e = e.next;
        }
        // 重试次数如果超过 MAX_SCAN_RETRIES，进入阻塞队列等待锁
        else if (++retries > MAX_SCAN_RETRIES) {
            lock(); // ReentrantLock的lock，加锁
            break;
        }
        else if ((retries & 1) == 0 &&
                 // 如果发生并发新元素倍插入，那么重新执行 scanAndLockForPut方法
                 (f = entryForHash(this, hash)) != first) {
            e = first = f; 
            retries = -1;
        }
    }
    return node;
}
```



**扩容rehash**

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Segment数组本身初始化后不能扩容，只能针对Segment内部的哈希表进行扩容，扩容容量为2倍增长(满足2次幂容量)。

```java
private void rehash(HashEntry<K,V> node) {
    HashEntry<K,V>[] oldTable = table;
    int oldCapacity = oldTable.length;
    int newCapacity = oldCapacity << 1; // aka 2倍
    threshold = (int)(newCapacity * loadFactor);
    // 创建新哈希表
    HashEntry<K,V>[] newTable =
        (HashEntry<K,V>[]) new HashEntry[newCapacity];
    int sizeMask = newCapacity - 1; // 新的掩码
    // 遍历原数组，将原数组位置 i 处的链表拆分到 新数组位置 i 或 i+oldCap 两个位置
    for (int i = 0; i < oldCapacity ; i++) {
        HashEntry<K,V> e = oldTable[i];
        if (e != null) {
            HashEntry<K,V> next = e.next;
            // 假设原数组长度为 16，e 在 oldTable[3] 处，那么 idx 只可能是 3 或者是 3 + 16 = 19
            int idx = e.hash & sizeMask;
            if (next == null)   
                newTable[idx] = e;
            else {
                HashEntry<K,V> lastRun = e;
                int lastIdx = idx;

                // 通过 for 循环找到一个 lastRun 节点，该节点后的所有元素放到一起
                for (HashEntry<K,V> last = next;
                     last != null;
                     last = last.next) {
                    int k = last.hash & sizeMask;
                    if (k != lastIdx) {
                        lastIdx = k;
                        lastRun = last;
                    }
                }
                newTable[lastIdx] = lastRun;
                // 这些节点可能分配在另一个链表中，也可能分配到上面的那个链表中
                for (HashEntry<K,V> p = e; p != lastRun; p = p.next) {
                    V v = p.value;
                    int h = p.hash;
                    int k = h & sizeMask;
                    HashEntry<K,V> n = newTable[k];
                    newTable[k] = new HashEntry<K,V>(h, p.key, v, n);
                }
            }
        }
    }
    // 将新来的 node 放到新数组中链表的头部
    int nodeIndex = node.hash & sizeMask; 
    node.setNext(newTable[nodeIndex]);
    newTable[nodeIndex] = node;
    table = newTable;
}
```



**size()方法**

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;size方法通过遍历获得当前分段对象的容量并求和就是ConcurrentHashMap的size，它会多次尝试（3次）非阻塞获得size大小，但如果期间被其他线程修改，（超过3次）则会对每个分段对象强制加锁进行容量获取，这就有点类似JVM的STW感觉。

```java
public int size() {
    final Segment<K,V>[] segments = this.segments;
    int size;
    boolean overflow; // 判断是否整型值溢出
    long sum;         // 记录被线程修改的次数modCount
    long last = 0L;   
    int retries = -1; // 自旋次数
    try {
        for (;;) {
            // 如果自旋达到3次则强制给每个Segment加锁
            if (retries++ == RETRIES_BEFORE_LOCK) {
                for (int j = 0; j < segments.length; ++j)
                    ensureSegment(j).lock(); // force creation
            }
            sum = 0L;
            size = 0;
            overflow = false;
            for (int j = 0; j < segments.length; ++j) {
                // 定位一个segment，获得其修改次数和容量
                Segment<K,V> seg = segmentAt(segments, j);
                if (seg != null) {
                    sum += seg.modCount;
                    int c = seg.count;
                    if (c < 0 || (size += c) < 0)
                        overflow = true;
                }
            }
            if (sum == last)
                break;
            last = sum;
        }
    } finally {
        // 如果尝试了三次说明segment被加锁，这里需要解锁
        if (retries > RETRIES_BEFORE_LOCK) {
            for (int j = 0; j < segments.length; ++j)
                segmentAt(segments, j).unlock();
        }
    }
    return overflow ? Integer.MAX_VALUE : size;
}
```

因为每个Segment的哈希表容量都是整型，如果数据量足够大，那么多个Segment的size之和就可能超出Integer的最大范围，此时需要通过overflow变量记录，如果容量爆表则只返回Integer.MAX_VALUE。