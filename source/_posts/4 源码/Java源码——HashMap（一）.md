---
title: Java源码——HashMap
date: 2020-5-7
tags: [源码]
---
{% asset_img image1.jpg HashMap %}

# HashMap（一）
<!--more-->

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;HashMap应该是Java世界应用最多的数据结构对象，HashMap从Java1.2开始存在，在Java8经过一次大改，Java5又出现了同步包java.util.concurrent其中就包含高性能的同步HashMap对象ConcurrentHashMap，这其中精彩世界以下揭晓。



## 0. 哈希表

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;哈希表，又称散列表，是计算机从业者最熟悉不过的数据结构，由于其在数据索引时只拥有O(n)时间复杂度而广泛应用。生活中我们也经常遇到类似情景，比如查字典过程、电话本黄页等等，通过索引关键字获得对应映射的值。

{% asset_img hashTable.png 哈希表 %}

上图为哈希表的简易示意图，哈希表的基本组成包括：

**桶**，是保存一组数据的空间，通常是一个链表（单向链表）或者一棵树（红黑树）；

**槽位**，是通过关键字定位数据桶的索引位置，通过关键字定位到槽位我们一般称为**落槽**。

**哈希冲突**，理想状态下每个槽位对应的桶只保存一个数据，那么就形成了槽位和数据一一对应关系（例如图中0号槽位和k号槽位），然而由于哈希表中的槽位通常是有限的，当数据量大于槽位个数时势必会产生一个槽位对应的桶中保存了多个数据，这就称为哈希冲突。解决哈希冲突的方式一般采用单向链表或者红黑树。

**哈希函数**，将数据元素的关键字key作为自变量，通过一定的函数关系计算出的值，即为该元素的存储地址，这个函数称为哈希函数。哈希函数需要解决的两大问题分别是均匀落槽和哈希冲突。前者在极端情况下会产生所有数据落槽在同一个桶中，产生空间资源浪费和性能低效。

**加载因子**（load factor），理想状态下，如果空间无限大则槽位可以保证只映射一个数据那么它的时间复杂度是完美的O(1)，如果空间有限，为了保证数据查询时间，可以将数据均分到每个桶中形成较短链路的链表，设计合理的哈希表可以平衡空间与时间。空间和时间永远是计算机领域的哲学问题，加载因子就是平衡这一问题的系数(0~1的浮点数)，研究表明，加载因子系数值越大空间损耗越小时间损耗越大，相反如果系数值越小空间损耗越大时间损耗越小，在Java中默认为0.75。

**再哈希**（rehash），当一个哈希表向槽位更多的哈希表迁移时，由于槽位个数发生变化，这就要求原哈希表中的每个元素重新计算哈希值并落槽到新哈希表中，这一过程称为rehash，是哈希表的重要性能指标之一。

<font color=red>*概念虽然较多，但都比较容易理解且重要*</font>

> 举个例子：
>
> 当我们需要从手机通讯录中查找某一个人的联系电话，这个过程可以拟化为一次哈希表的查找。
>
> 首先，有张三、李三、王三三个人的联系方式需要存入通讯录，我们假定他们的名字就是关键字，通过哈希函数计算关键字获得落槽位置分别是拼音首字母z、l和w，此时这个哈希表槽位数共有三个，每个槽位对应的桶分别是张三、李三、王三的电话号码，当我们需要拨打张三电话时直接找到z对应的电话拨出即可。
>
> 然而，又来了三个人需要保存电话，他们分别是张四、李四、王四，通过哈希函数计算名字关键字得到槽位还是z、l和w，这就是哈希冲突，三个槽位对应的桶分别保存了两个电话号码，当我们拨打张四电话时，需要先找到z，在从z的列表中找到张四电话并拨出。
>
> 最后，又来了两个人赵三和刘三，很明显目前的通讯录无法保存他们的电话，这时我们需要对通讯录扩容并将现在的六个人电话迁移过去，但是迁移时需要满足一个约束，原来的六个人必须都重新通过哈希函数计算落槽位置，这就是rehash。





## 1. JAVA 7的实现

**成员变量**

HashMap的实现实际是一个桶数组或者称为链表数组，数组下标索引即槽位，同时定义了默认的加载因子、初始容量、最大范围和扩容条件。

```java
public class HashMap<K,V> extends AbstractMap<K,V> 
    implements Map<K,V>, Cloneable, Serializable
{
    static final int DEFAULT_INITIAL_CAPACITY = 1 << 4; // HashMap的默认初始大小16
    
    static final int MAXIMUM_CAPACITY = 1 << 30; // HashMap允许的最大范围2^30
    
    static final float DEFAULT_LOAD_FACTOR = 0.75f; // 默认加载因子
    
    /**
     * The table, resized as necessary. Length MUST Always be a power of two.
     */
    // table就是哈希表，它实际是一个桶数组或者链表数组，官方注释表明哈希表容量必须满足2的幂(向上取值)
    transient Entry<K,V>[] table = (Entry<K,V>[]) EMPTY_TABLE;
    
    transient int size; // 当前HashMap以保存数据的个数
    
    // HashMap扩容阈值，threshlod = capacity * loadFactor,如果size >= threshlod则需要扩容，而并非size == table.length。
    int threshold; 
    
    /**
     * A randomizing value associated with this instance that is applied to
     * hash code of keys to make hash collisions harder to find. If 0 then
     * alternative hashing is disabled.
     */
    // 哈希种子，哈希冲突更难被发现
    transient int hashSeed = 0;
}
```



Java7采用单向链表来解决哈希冲突，以下是定义的私有内部类链表节点

```java
static class Entry<K,V> implements Map.Entry<K,V> {
    final K key; // 关键字
    V value;	// 值
    Entry<K,V> next; // 后继
    int hash; // 哈希值
    ...
}
```



**put方法**

put方法是研究HashMap的精髓，掌握了该方法也就基本掌握HashMap的原理。

```java
public V put(K key, V value) {
    if (table == EMPTY_TABLE) {
        inflateTable(threshold); // 空表时扩容默认大小的哈希表
    }
    if (key == null)
        return putForNullKey(value); // HashMap允许存在一个关键字为null的值（区别于HashTable）
    int hash = hash(key); // 哈希函数，求关键字对应的哈希值，如下方法
    int i = indexFor(hash, table.length); // 计算落槽位置，如下方法

    // 遍历槽位对应的链表，从第一个节点开始
    for (Entry<K,V> e = table[i]; e != null; e = e.next) { 
        Object k;
        // 当哈希值相同并且key相同时则在链表中找到了对应数据，更改value值
        if (e.hash == hash && ((k = e.key) == key || key.equals(k))) {
            V oldValue = e.value;
            e.value = value;
            e.recordAccess(this);
            return oldValue;
        }
    }

    modCount++;
    // 如果链表没有找到数据则说明是新数据，将该数据添加到链表头部，如果容量达到阈值，则需要扩容，对旧表做迁移，需要rehash，如下方法。
    addEntry(hash, key, value, i);
    return null;
}


// 关键的哈希函数，由复杂的移位和异或等位运算组成，为了保证发生哈希冲突时，数据可以均匀落槽
// 当加载因子默认是0.75时，哈希冲突最多为8个。
final int hash(Object k) {
    int h = hashSeed;
    if (0 != h && k instanceof String) {
        return sun.misc.Hashing.stringHash32((String) k);
    }
    h ^= k.hashCode();
    // This function ensures that hashCodes that differ only by
    // constant multiples at each bit position have a bounded
    // number of collisions (approximately 8 at default load factor).
    h ^= (h >>> 20) ^ (h >>> 12);
    return h ^ (h >>> 7) ^ (h >>> 4);
}


// 1.参数h是哈希函数计算的哈希值，length是哈希表的长度，将哈希值与length-1求与操作可以保证索引在length范围内
// 2.在哈希表中每个元素的操作都离不开落槽，通常采用模运算，但模运算在计算机原理中是比较耗时的方式，所以HashMap要求容量必须是2次幂，这样依据二进制特点，length-1永远是多个1的排列，这样与运算就是与h的对位与，效率更高。
static int indexFor(int h, int length) {
    // assert Integer.bitCount(length) == 1 : "length must be a non-zero power of 2";
    return h & (length-1);
}


void addEntry(int hash, K key, V value, int bucketIndex) {
    // 如果当前size达到阈值则扩容并数据迁移
    if ((size >= threshold) && (null != table[bucketIndex])) {
        resize(2 * table.length); // 扩容和rehash
        hash = (null != key) ? hash(key) : 0;
        bucketIndex = indexFor(hash, table.length);
    }

    createEntry(hash, key, value, bucketIndex);
}

// 新数据添加到链表头部
void createEntry(int hash, K key, V value, int bucketIndex) {
    Entry<K,V> e = table[bucketIndex];
    table[bucketIndex] = new Entry<>(hash, key, value, e);
    size++;
}

// 扩容新表容量是旧表的2倍（保证2次幂）
void resize(int newCapacity) {
    Entry[] oldTable = table;
    int oldCapacity = oldTable.length;
    if (oldCapacity == MAXIMUM_CAPACITY) {
        threshold = Integer.MAX_VALUE;
        return;
    }

    Entry[] newTable = new Entry[newCapacity];
    transfer(newTable, initHashSeedAsNeeded(newCapacity)); // 数据迁移
    table = newTable;
    threshold = (int) Math.min(newCapacity * loadFactor, MAXIMUM_CAPACITY + 1);
}

// 数据迁移，需要对旧表每个数据重新计算哈希值
void transfer(Entry[] newTable, boolean rehash) {
    int newCapacity = newTable.length;
    for (Entry<K,V> e : table) {
        while(null != e) {
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



**哈希函数**

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;哈希函数对String类型做了特殊处理，实际上是调用了String类中的hash32()方法，计算获得String类型的32位哈希值，native底层使用murmur3_32()哈希方法而非String的hashCode()方法，原因是**因为hashCode()方法将字符串的每个字符Unicode值累加获得，如果使用String作为key的话这样的处理方式会增加哈西冲突的概率**。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;同时可以看到哈希函数入参是对象，计算哈希码过程中也使用到了对象的hashCode方法，也就是说，**哈希函数依赖对象自身的哈希码，并以此额外计算了新的哈希码供HashMap使用，这样的好处是可以防止低质量的哈希函数。**

```java
// HashMap 哈希函数
final int hash(Object k) {
    int h = hashSeed;
    // 字符串哈希值
    if (0 != h && k instanceof String) {
        return sun.misc.Hashing.stringHash32((String) k);
    }

    h ^= k.hashCode(); // 对象自身哈希码
    h ^= (h >>> 20) ^ (h >>> 12);
    return h ^ (h >>> 7) ^ (h >>> 4);
}

// String的hashCode方法和hash32方法
// 每个字符Unicode码累加
public int hashCode() {
    int h = hash;
    if (h == 0 && value.length > 0) {
        char val[] = value;
        for (int i = 0; i < value.length; i++) {
            h = 31 * h + val[i];
        }
        hash = h;
    }
    return h;
}

// 底层使用murmur3_32方法
int hash32() {
    int h = hash32;
    if (0 == h) {
        // harmless data race on hash32 here.
        h = sun.misc.Hashing.murmur3_32(HASHING_SEED, value, 0, value.length);
        // ensure result is not zero to avoid recalcing
        h = (0 != h) ? h : 1;
        hash32 = h;
    }
    return h;
}
```

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;在不同的编码规范中都要求软件工程师重写equals方法时要重写hashCode方法，从HashMap中就可以看出，当新元素落槽之后，链表从头结点开始比较的第一个条件就是对象的哈希值是否相等，且这一条件是短路的，即使key的值相同也会认为是不同的对象。

```java
public V put(K key, V value) {
   ...
    // 遍历槽位对应的链表，从第一个节点开始
    for (Entry<K,V> e = table[i]; e != null; e = e.next) { 
        Object k;
        // 首先比较哈希码，且是短路条件，不满足立刻退出，即使key相等
        if (e.hash == hash && ((k = e.key) == key || key.equals(k))) {
            V oldValue = e.value;
            e.value = value;
            e.recordAccess(this);
            return oldValue;
        }
    }
    ...
}
```

所以建议采用《Effective Java》中的第8、9条条例，小心的设计自己对象的equals和hashCode方法。假如，两个方法设计糟糕将会导致该对象作为key保存在HashMap中时，当对该对象执行get或put等操作，即使客观上两者是相同的对象，也会被区别对待，最终导致HashMap产生内存泄漏问题。



**落槽方法indexFor**

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;在解决哈希冲突问题上，通常采用取余操作将数据均分到不同桶中，然而在计算机中取余操作相比于其他逻辑运算比较消耗性能，首先需要对数值转换十进制，然后不断的执行被除数和除数的除法操作最终获得余数，这在大范围使用上是不合适的，HashMap采用对2次幂减1并求异或是在二进制层面的位运算，效率很高更适合作为解决哈希冲突的手段，唯一约束就是要求容量必须保证是2次幂

```java
static int indexFor(int h, int length) {
    return h & (length-1);
}
```

> 假设，整型h=101，length=8，s=length-1=7
>
> h对应二进制是
>
> <font color=red>0000 0000 0000 0000 0000 0000 0110 0101‬</font>
>
> length对应二进制是
>
> 0000 0000 0000 0000 0000 0000 0001 0000
>
> length-1对应的二进制是
>
> <font color=red>0000 0000 0000 0000 0000 0000 0000 1111</font>
>
> 按照异或的特性会将h的高位全部截断只保留与h对应的位数
>
> <font color=red>0000 0000 0000 0000 0000 0000 0000 0101‬</font>
>
> 相当于求0101^1111，最终的哈希值是0101，即5



**内存泄漏**

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;通过源码可以看到，比较元素相等时优先比较哈希码是否相等，再短路比较key相等，所以使用HashMap时需要保证：

1. 作为键值Key必须是不可变的。
2. 如果使用类作为Key，那该类最好是是不可变类。
3. 如果不是不可变类，那应该保证同时重写equals方法和hashCode方法，并且重写的hashCode方法是无状态的，即状态不可变，不会使用可变的依赖值，否则会导致理论上同一对象却有两种不同的hashCode，最终使HashMap发生内存泄漏。

> 内存溢出：存储容量过多且GC无法回收，导致内存使用量达到JVM阈值，发生OOM。
>
> 内存泄漏：对象以后不会被访问，但由于某些原因（在可用的GC ROOT上）GC无法回收，导致无效数据占用内存空间并最终发生OOM。