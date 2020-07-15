---
title: Java源码——TreeMap和红黑树
date: 2020-5-15
tags: [源码]
---
{% asset_img image1.jpg HashMap %}

# TreeMap和红黑树
<!--more-->

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;红黑树与AVL树类似，都可以在插入和删除时通过旋转来保持自身树的平衡，从而获得较高的查找性能。**与AVL树相比，红黑树并不是严格的平衡树，只要保证从根节点出发到叶子节点的最长路径不超过最短路径的2倍，最坏情况算法复杂度依然可以保证O（logn）。**

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;红黑树的每个节点都会着色，要么是黑色要么是红色，通过重新着色和左右旋转完成自身平衡的调整，它需要满足以下4个要求：

1. 节点只能是红色或者黑色。
2. 根节点和NIL节点必须是黑色。
3. 一条路径不能存在连续的两个红色节点。
4. 任何树内，根节点到叶子节点的路径上包含相同黑色节点的个数。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;NIL是每个叶子节点有两个NIL子节点，NIL节点物理上并不存在，只存在与逻辑空间，主要是为了满足红黑树自旋稳定性。**红黑树的旋转在3次之内可以达到平衡**。



## TreeMap

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;TreeMap适用于对key有排序要求的场景中，TreeMap使用红黑树作为底层数据结构，TreeMap继承自AbstractMap并实现了NavigableMap接口，该接口要求提供排序算法。作为TreeMap的key必须具有比较能力Comparable或者自定义实现比较器Comparator以支持排序规定，所以key不允许为null。

```java
public class TreeMap<K,V> extends AbstractMap<K,V>
    implements NavigableMap<K,V>, Cloneable,Serializable
    
```

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;TreeMap优先使用比较器Comparator，如果比较器不存在则使用key自然排序Comparable，如果两者都不存在则会抛出异常`ClassCastException`



**成员变量和构造器**

```java
//　全局比较器
private final Comparator<? super K> comparator;

// 根节点
private transient Entry<K,V> root;

private transient int size = 0;
private transient int modCount = 0;

// boolean类型表示红黑两色
private static final boolean RED   = false;
private static final boolean BLACK = true;

// 内部类，红黑树节点，其中color是节点的颜色
static final class Entry<K,V> implements Map.Entry<K,V> {
    K key;
    V value;
    Entry<K,V> left;
    Entry<K,V> right;
    Entry<K,V> parent;
    boolean color = BLACK;
｝

// 默认构造器，比较器为null
public TreeMap() {
    comparator = null;
}

// 带自定义比较器的构造器
public TreeMap(Comparator<? super K> comparator) {
        this.comparator = comparator;
    }

// 使用有序Map的比较器，并将数据转移
public TreeMap(SortedMap<K, ? extends V> m) {
        comparator = m.comparator();
        try {
            buildFromSorted(m.size(), m.entrySet().iterator(), null, null);
        } catch (java.io.IOException cannotHappen) {
        } catch (ClassNotFoundException cannotHappen) {
        }
    }
```



**结构调整**

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;红黑树的结构变化发生在数据的插入和删除，一旦发生变化红黑树的平衡就有可能被破坏，这时就需要旋转重新达到平衡。需要考虑以下三种条件：

1. 被调整的节点总是红色节点。
2. 如果新增节点的父节点是黑色的就无需改变，因为可以保证红黑树的约束。
3. 如果新节点的父节点是红色，需要进行重新着色、左右旋转最终达到约束条件重新保持红黑树的平衡。



**插入数据**

​    TreeMap的插入就是按照key的比较进行遍历，按照二分查找的特点**大于当前节点向右遍历，小于当前节点向左遍历**，当确定节点之后再考虑着色和旋转，保证红黑树的约束。

**put()方法**

``` java
public V put(K key, V value) {
    // t表示当前节点
    Entry<K,V> t = root;
    // 如果当前是空树，则新插入数据设为根
    if (t == null) {
        compare(key, key); // type (and possibly null) check
        root = new Entry<>(key, value, null);
        size = 1;
        modCount++;
        return null;
    }
    // 接收比较结果
    int cmp;
    Entry<K,V> parent;
    Comparator<? super K> cpr = comparator;
    // 比较方式分支
    if (cpr != null) {
        // 循环目标：入参key与当前节点key不断比较
        do {
            parent = t;
            // 比较当前key和入参key
            cmp = cpr.compare(key, t.key);
            if (cmp < 0)
                t = t.left; //小就置为左节点
            else if (cmp > 0)
                t = t.right; //大置为右节点
            else
                return t.setValue(value); //相等覆盖
            // 如果没有相等节点，则会进入NIL节点
        } while (t != null);
    } else {
        // 使用Comparable不允许key为空
        if (key == null)
            throw new NullPointerException();
        @SuppressWarnings("unchecked")
        Comparable<? super K> k = (Comparable<? super K>) key;
        do {
            parent = t;
            cmp = k.compareTo(t.key);
            if (cmp < 0)
                t = t.left;
            else if (cmp > 0)
                t = t.right;
            else
                return t.setValue(value);
        } while (t != null);
    }
    // 新节点创建并根据比较结果置于父节点的左或右节点
    Entry<K,V> e = new Entry<>(key, value, parent);
    if (cmp < 0)
        parent.left = e;
    else
        parent.right = e;
    // 对新节点着色和旋转达到平衡
    fixAfterInsertion(e);
    size++;
    modCount++;
    return null;
}

// 选择比较方法
final int compare(Object k1, Object k2) {
    return comparator==null ? ((Comparable<? super K>)k1).compareTo((K)k2)
        : comparator.compare((K)k1, (K)k2);
}
```

由于TreeMap通过比较来判断key的唯一性，所以equals和hashCode方法不是必须覆写的。



**fixAfterInsertion()方法**

```java
private void fixAfterInsertion(Entry<K,V> x) {
    // 新节点着色为红色，满足约束条件1
    x.color = RED;

    // 遍历使树达到平衡的条件
    while (x != null && x != root && x.parent.color == RED) {
        // 如果父节点是祖父节点的左子节点
        if (parentOf(x) == leftOf(parentOf(parentOf(x)))) {
            // 查看父节点的兄弟节点（右叔）颜色
            Entry<K,V> y = rightOf(parentOf(parentOf(x)));
            if (colorOf(y) == RED) { // 如果右叔节点是红色
                setColor(parentOf(x), BLACK); // 父节点着黑色
                setColor(y, BLACK); // 右叔节点着黑色
                setColor(parentOf(parentOf(x)), RED); // 祖父节点着红色
                x = parentOf(parentOf(x));// 当前节点指向红色的祖父节点
            } else { // 如果右叔节点是黑色
                if (x == rightOf(parentOf(x))) {
                    x = parentOf(x); // 当前节点指向红色的父节点
                    rotateLeft(x); // 左旋调整平衡
                }
                setColor(parentOf(x), BLACK); // 父节点着黑色
                setColor(parentOf(parentOf(x)), RED); // 祖父节点着红色
                rotateRight(parentOf(parentOf(x))); // 左旋红色的祖父节点
            }
        } else {// 如果父节点是祖父节点的右子节点，过程与上述类似
            Entry<K,V> y = leftOf(parentOf(parentOf(x)));
            if (colorOf(y) == RED) {
                setColor(parentOf(x), BLACK);
                setColor(y, BLACK);
                setColor(parentOf(parentOf(x)), RED);
                x = parentOf(parentOf(x));
            } else {
                if (x == leftOf(parentOf(x))) {
                    x = parentOf(x);
                    rotateRight(x);
                }
                setColor(parentOf(x), BLACK);
                setColor(parentOf(parentOf(x)), RED);
                rotateLeft(parentOf(parentOf(x)));
            }
        }
    }
    root.color = BLACK;
}
// 左旋
private void rotateLeft(Entry<K,V> p) {
    if (p != null) {
        Entry<K,V> r = p.right;
        p.right = r.left;
        if (r.left != null)
            r.left.parent = p;
        r.parent = p.parent;
        if (p.parent == null)
            root = r;
        else if (p.parent.left == p)
            p.parent.left = r;
        else
            p.parent.right = r;
        r.left = p;
        p.parent = r;
    }
}

// 右旋
private void rotateRight(Entry<K,V> p) {
    if (p != null) {
        Entry<K,V> l = p.left;
        p.left = l.right;
        if (l.right != null) l.right.parent = p;
        l.parent = p.parent;
        if (p.parent == null)
            root = l;
        else if (p.parent.right == p)
            p.parent.right = l;
        else p.parent.left = l;
        l.right = p;
        p.parent = l;
    }
}
```

使用左旋或者右旋的条件：

1. 父节点是红色，叔叔节点是红色，则重新着色。

2. 父节点时红色，叔叔节点是黑色，如果新节点是父节点的左节点，右旋。

3. 父节点时红色，叔叔节点是黑色，如果新节点是父节点的右节点，左旋。

   

**插入举例**

```java
TreeMap<Integer, String> treeMap = new TreeMap<>();
treeMap.put(13,"");
treeMap.put(14,"");
treeMap.put(15,"");
treeMap.put(16,"");
treeMap.put(42,"");
treeMap.remove(15);
treeMap.put(20,"");
// 从空树开始演示红黑树插入，调整平衡的过程。
```

> 插入13、14、15

{% asset_img treemap1.png TreeMap%}



> 插入16

{% asset_img treemap2.png TreeMap%}



> 插入42

{% asset_img treemap3.png TreeMap%}



> 删除15，插入20

{% asset_img treemap4.png TreeMap%}



**AVL树和红黑树**

1. 时间复杂度：对于任意高度的节点，它的黑深度满足**≥ height / 2**，即对于任意包含n个节点的红黑树，它的根节点高度**h≤2log2 (n+1)**，当树失去平衡，时间复杂度有可能变为O(n)，即h=n。所以，可以保证树的高度始终保持在O(logn)时，所有操作的时间复杂度保持在O(logn)以内。
2. 平衡性：AVL是严格的平衡二叉查找树，任意子树的高度差始终在1以内，红黑树平衡没有如此严格，所以当节点个数一致，红黑树的高度可能大于AVL树，换句话说，平均查找次数会高于相同情况下的AVL树。**插入时**，两者都可以保证最多两次旋转就可以使树恢复平衡；**删除时**，由于红黑树对高度差的不严格，最多三次就可以恢复平衡，而AVL可能需要更多的旋转。**因此，频繁的插入和删除红黑树更合适；低频修改，高频查询AVL树更合适**