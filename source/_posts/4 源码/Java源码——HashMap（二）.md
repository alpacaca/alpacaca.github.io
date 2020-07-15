---
title: Java源码——HashMap
date: 2020-5-7
tags: [源码]
---
{% asset_img image1.jpg HashMap%}

# HashMap（二）
<!--more-->

> 说明：文章部分内容来自https://coolshell.cn/articles/9606.html

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;JDK7中的HashMap是线程不安全的，尽管官方文档明确声明并发情况下不能使用，但在问题列表例总能找到强行使用的童鞋，这就会导致一个严重的问题：死链，通过恢复现场就能找到线程在调用get()方法时被堵死，重启可以临时清空内存，但时间一长又会复现。

**死链**

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;死链又称为无限循环（HashMap Infinite Loop），一旦产生死链，系统的CPU就飙满，导致fatal级系统问题。其根本原因主要发生在扩容方法resize()时将旧数据移动到新容器的过程中，以下通过源码来看。

```java
void resize(int newCapacity) {
    Entry[] oldTable = table;
    int oldCapacity = oldTable.length;
    if (oldCapacity == MAXIMUM_CAPACITY) {
        threshold = Integer.MAX_VALUE;
        return;
    }

    Entry[] newTable = new Entry[newCapacity];
    // 注意transfer方法
    transfer(newTable, initHashSeedAsNeeded(newCapacity));
    table = newTable;
    threshold = (int)Math.min(newCapacity * loadFactor, MAXIMUM_CAPACITY + 1);
}

void transfer(Entry[] newTable, boolean rehash) {
    int newCapacity = newTable.length;
    for (Entry<K,V> e : table) {
        while(null != e) {
            // 数据迁移时发生死链场景
            Entry<K,V> next = e.next;
            if (rehash) {
                e.hash = null == e.key ? 0 : hash(e.key);
            }
            int i = indexFor(e.hash, newCapacity);
            e.next = newTable[i];
            newTable[i] = e;
            e = next;
        }
    }
}
```

当两个线程Thread1和Thread2交替执行transfer注释部分的代码时，有可能导致如下图的链表指向情况。

{% asset_img infinitloop.jpg 死链 %}

当执行Thread1的get(key)方法时，恰好该key落槽到死链的桶中，链表的循环遍历就会在3和7之间无限循环，拉满CPU使用率。

> 虽然该问题很快被SUN发现，但被认为HashMap本来就是线程非安全并不应该用在并发场景下，可以使用ConcurrentHashMap代替，所以在多个大小版本中一直没有解决更新，直到JDK8发布。



## 2 JDK8 HashMap

**改进总结**

1. 将桶内数据结构仅支持链表改为同时支持链表+红黑树。

2. 针对死链问题，改进扩容时的插入顺序。

3. 新增lambda表达式支持函数，如forEach()。

4. 新增API：replace()和merge()

   

> - 在源码浏览时，如果与JDK7相同则不重复介绍
>
> - 由于整体源码写作风格与当前流行的编码规范格格不入（圈复杂度高，变量不优先初始化而是首次调用初始化，排版有些随意）可能会引起阅读的不适……

**成员变量**

```java
// 红黑树转换阈值，当桶内数据容量达到8时，会将链表转变为红黑树
static final int TREEIFY_THRESHOLD = 8; 
// 当删除或容器扩容，桶内容量减少到6时会还原回链表
static final int UNTREEIFY_THRESHOLD = 6;
// 红黑树桶的最小容量是64
static final int MIN_TREEIFY_CAPACITY = 64;
```

一般来说，当哈希码分布均匀时，很少会产生红黑树桶，**TREEIFY_THRESHOLD**设置为8从离散随机分布的角度来看满足**泊松分布，即加载因子在默认0.75时，红黑树转换阈值达到8的概率是比较低的**，因为虽然红黑树提高了元素的遍历查找和修改的效率，但是空间上比链表占用二倍的内存，同时树化的过程是需要消耗时间的。**总结，链表转换红黑树的前提是哈希函数设计不合理导致大量哈希冲突，设计良好的哈希函数不会也没有必要树化。**

```java
// 官方注释
/* Because TreeNodes are about twice the size of regular
nodes, we use them only when bins contain enough nodes to warrant use(see TREEIFY_THRESHOLD). And when they become too small (due to removal or resizing) they are converted back to plain bins. In usages with well-distributed user hashCodes, tree bins are rarely used. Ideally, under random hashCodes, the frequency of nodes in bins follows a Poisson distribution(http://en.wikipedia.org/wiki/Poisson_distribution) with a parameter of about 0.5 on average for the default resizing threshold of 0.75, although with a large variance because of resizing granularity. Ignoring variance, the expected occurrences of list size k are (exp(-0.5) * pow(0.5, k)/factorial(k)). The first values are:
0: 0.60653066
1: 0.30326533
2: 0.07581633
3: 0.01263606
4: 0.00157952
5: 0.00015795
6: 0.00001316
7: 0.00000094
8: 0.00000006
*/
static final int TREEIFY_THRESHOLD = 8; 
```



> 泊松分布与加载因子无关，而是量化发生树化的概率；加载因子与哈希表的容量有关。
>
> 比如:
>
> 默认容量capacity = 16，可放数据量为threshold = capacity * loadfactor = 16 * 0.75 = 12，那么一个桶内放入8个元素（树化阈值）的概率是0.00000006（泊松分布概率）。
>
> 同理，当容器扩容到64时，threshold = capacity * loadfactor = 64 * 0.75 = 48, 那么一个桶内放入8个元素的概率还是0.00000006。



**put方法**

同样的，put方法永远是研究HashMap的精髓。

```java
public V put(K key, V value) {
    // putVal先计算key的哈希码，hashCode值高16位与低16异或
    return this.putVal(hash(key), key, value, false, true);
}

final V putVal(int hash, K key, V value, boolean onlyIfAbsent,
               boolean evict) {
    Node<K,V>[] tab; Node<K,V> p; int n, i;
    // 空表初始化并赋值
    if ((tab = table) == null || (n = tab.length) == 0)
        n = (tab = resize()).length;
    // 落位i = (n-1) & hash如果元素不存在则在桶中新建节点
    if ((p = tab[i = (n - 1) & hash]) == null)
        tab[i] = newNode(hash, key, value, null);
    else {
        Node<K,V> e; K k;
        // 如果桶内头元素是目标元素，则更新数据
        if (p.hash == hash &&
            ((k = p.key) == key || (key != null && key.equals(k))))
            e = p;
        // 如果桶内是红黑树则调用红黑树方法保存节点
        else if (p instanceof TreeNode)
            e = ((TreeNode<K,V>)p).putTreeVal(this, tab, hash, key, value);
        // 如果桶内是链表则调用链表方法保存节点
        else {
            for (int binCount = 0; ; ++binCount) {
				 // 插入数据（尾插），桶内元素个数达到树化阈值则跳出循环进行树化
                if ((e = p.next) == null) {
                    p.next = newNode(hash, key, value, null);
                    if (binCount >= TREEIFY_THRESHOLD - 1) // -1 for 1st
                        treeifyBin(tab, hash);
                    break;
                }
                // 链表插入数据
                if (e.hash == hash &&
                    ((k = e.key) == key || (key != null && key.equals(k))))
                    break;
                p = e;
            }
        }
        if (e != null) { // existing mapping for key
            V oldValue = e.value;
            // onlyIfAbsent指如果元素相同新指替换旧值
            if (!onlyIfAbsent || oldValue == null)
                e.value = value;
            afterNodeAccess(e);
            return oldValue;
        }
    }
    ++modCount;
    if (++size > threshold)
        resize();
    afterNodeInsertion(evict);
    return null;
}

// 以下三个方法是LinkedHashMap的实现方法，
void afterNodeAccess(Node<K,V> p) { }
void afterNodeInsertion(boolean evict) { }
void afterNodeRemoval(Node<K,V> p) { }
```

1. JAVA7的HashMap在新增数据时是将新数据插入桶内头部，而JAVA8采用在链表尾部插入数据。
2. 源码中的变量初始化赋值发生在第一次调用点，所以阅读起来并不顺畅。
3. 哈希函数和落位操作比JAVA7更加简洁且直观。
4. 元素相等判断不变，还是以哈希码相等开始并且是短路的（考虑内存泄漏可能）。



**落槽操作**

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;JAVA8没有为落槽操作单独写一个方法，而是采用`table[i = (n-1) * hash]`来完成，其实这与JAVA7中的操作一样`h & (length-1)`，都依赖2次幂的容量。但JAVA8利用按位与的特性巧（骚）妙（操）地（作）解决了开篇所说的死链问题，介绍扩容方法时将详细说明。



**哈希函数**

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;新的hash方法，对象hashCode与自身右移16位求异或，相比JDK7的实现“清爽”了许多， 我们知道int类型是32位，右移16位再异或，就相当于将高16位和低16位进行异或操作。

```java
static final int hash(Object key) {
    int h;
    return key == null ? 0 : (h = key.hashCode()) ^ h >>> 16;
}
```



**扩容方法**

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;扩容方法resize()不仅支撑扩容，还会初始化容器（将容器初始化放到第一次调用位置，减少内存无效开销），与JAVA7一样，初始默认容量是16，加载因子0.75f，阈值=加载因子*容量，为了高效落位容量适中保持2次幂，扩容为2倍。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;为了解决开头说的并发死链问题，巧妙地利用落槽操作时用到的按位与操作特性保证了数据迁移的顺序问题，保证数据不会发生错位。介绍源码之前先简单的介绍一下原理：

> 说明：按位与会截断高位数据，只保留与低位一样的位数。
>
> 假设哈希码是1010 0101 1100 0011 1101 0100 1011 1001
>
> - 假设，初始容量是capacity = 16，capacity - 1对应的二进制是
>
>   0000 0000 0000 0000 0000 0000 0000 1111
>
>   与哈希码按位与时，哈希码高位截断，只保留与容量位数一致，可以简写为：
>
>   1001 & 1111，结果是<font color=red>1001</font>
>
> - 当容量扩容后capacity = 32, capacity -1 对应的二进制是
>
>   0000 0000 0000 0000 0000 0000 0001 1111
>
>   与哈希码按位与时，哈希码高位截断，只保留与容量位数一致，可以简写为：
>
>   11001 & 11111，结果是<font color=red>11001</font>
>
> - 从两次的按位与结果来看，低位<font color=red>1001</font>不变，只有高位<font color=red>1</font>变化（<font color=red>11001</font>），这个变化与具体的哈希码有关，但无非是0或者1，所以JAVA8扩容方法抓住这一特性使得：**数据迁移时，如果rehash后高位是0，则该数据保持在原来桶的位置不变；如果高位是1，则该数据重新分配到新空间的桶中。这样就避免了rehash重新分配所有数据落槽位置，导致元素顺序引用发生改变，从而引起并发下的死链。**

```java
final Node<K,V>[] resize() {
    Node<K,V>[] oldTab = table;
    int oldCap = (oldTab == null) ? 0 : oldTab.length;
    int oldThr = threshold;
    int newCap, newThr = 0;
    // 设定阈值
    if (oldCap > 0) {
        if (oldCap >= MAXIMUM_CAPACITY) {
            threshold = Integer.MAX_VALUE;
            return oldTab;
        }
        else if ((newCap = oldCap << 1) < MAXIMUM_CAPACITY &&
                 oldCap >= DEFAULT_INITIAL_CAPACITY)
            newThr = oldThr << 1; // double threshold
    }
    else if (oldThr > 0) // initial capacity was placed in threshold
        newCap = oldThr;
    // 初始化HashMap容量和阈值
    else {               // zero initial threshold signifies using defaults
        newCap = DEFAULT_INITIAL_CAPACITY;
        newThr = (int)(DEFAULT_LOAD_FACTOR * DEFAULT_INITIAL_CAPACITY);
    }
    if (newThr == 0) {
        float ft = (float)newCap * loadFactor;
        newThr = (newCap < MAXIMUM_CAPACITY && ft < (float)MAXIMUM_CAPACITY ?
                  (int)ft : Integer.MAX_VALUE);
    }
    threshold = newThr;
    @SuppressWarnings({"rawtypes","unchecked"})
    Node<K,V>[] newTab = (Node<K,V>[])new Node[newCap];
    table = newTab;
    if (oldTab != null) {
        for (int j = 0; j < oldCap; ++j) {
            Node<K,V> e;
            if ((e = oldTab[j]) != null) {
                oldTab[j] = null;
                if (e.next == null)
                    newTab[e.hash & (newCap - 1)] = e;
                else if (e instanceof TreeNode)
                    ((TreeNode<K,V>)e).split(this, newTab, j, oldCap);
                // 官方备注“维持顺序”
                // hi前缀变量表示高位，lo前缀表示低位
                else { // preserve order
                    Node<K,V> loHead = null, loTail = null;
                    Node<K,V> hiHead = null, hiTail = null;
                    Node<K,V> next;
                    do {
                        next = e.next;
                        // 注意是oldCap，而不是oldCap-1,此时与操作就是只看上面提到的二进制高位
                        // 二进制高位是0
                        if ((e.hash & oldCap) == 0) {
                            if (loTail == null)
                                loHead = e; 
                            else
                                loTail.next = e;
                            loTail = e;
                        }
                        // 二进制高位是1
                        else {
                            if (hiTail == null)
                                hiHead = e;
                            else
                                hiTail.next = e;
                            hiTail = e;
                        }
                    } while ((e = next) != null);
                    if (loTail != null) {
                        loTail.next = null;
                        newTab[j] = loHead; // 原来桶内
                    }
                    if (hiTail != null) {
                        hiTail.next = null;
                        newTab[j + oldCap] = hiHead; // 新分配空间桶内
                    }
                }
            }
        }
    }
    return newTab;
}
```

至此，HashMap源码介绍完毕，新API将在未来lambda表达式中详细介绍（可能）（手动狗头）。