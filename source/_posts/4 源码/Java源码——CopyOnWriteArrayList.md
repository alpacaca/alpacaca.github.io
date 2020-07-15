---
title: Java源码——CopyOnWriteArrayList
date: 2020-5-11
tags: [源码, COW]
---
{% asset_img image1.jpg 算法 %}

# CopyOnWriteArrayList
<!--more-->

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Copy-On-Write（COW）技术是Linux底层采用的策略，称为写时复制技术，它的核心思想是**针对读多写少的场景，多线程读时不上锁，只有当写时会对数据进行拷贝并加锁，在产生的副本上修改，并最终合入源数据**，在JUC中，CopyOnWriteArrayList是针对ArrayList的COW版本，CopyOnWriteArraySet是针对Set的COW版本，以前者为例，在读多写少的场景时，比如订单地址、缓存系统等，读取列表是支持多线程同时访问的，并不会产生读阻塞（与读写锁的区别），当修改列表数据时会创建当前集合的副本，加锁并修改，最终将数据集成到集合中。由此可以看出：

1. CopyOnWriteArrayList在多线程读操作时，与ArrayList一致，不会产生读阻塞。
2. 修改时创建原集合大小的副本，会占用更多的系统内存，如果并发写过大时就有可能产生频繁的Major GC，甚至出现OOM。此时需要考虑替换其他集合。
3. 存在并发写操作时，读操作仍旧只能读取旧数据。



**成员变量**

```java
public class CopyOnWriteArrayList<E>
    implements List<E>, RandomAccess, Cloneable, java.io.Serializable {
    
    final transient Object lock = new Object(); // 内置监视器，使用synchronized
    private transient volatile Object[] array; //数组容器
}
```



**get 方法**

```java
// 通过下标正常读取数组中的数据
public E get(int index) {
    return elementAt(getArray(), index);
}

static <E> E elementAt(Object[] a, int index) {
    return (E) a[index];
}
```



**add 、set 和 remove 方法**

```java
// 不指定索引新增
public boolean add(E e) {
    synchronized (lock) { // 写入时加锁
        Object[] es = getArray();
        int len = es.length;
        es = Arrays.copyOf(es, len + 1); // 创建当前数组的副本并修改元素
        es[len] = e;
        setArray(es);
        return true;
    }
}

// 指定索引新增，原理相同
public void add(int index, E element) {
    synchronized (lock) {
        Object[] es = getArray();
        int len = es.length;
        if (index > len || index < 0)
            throw new IndexOutOfBoundsException(outOfBounds(index, len));
        Object[] newElements;
        int numMoved = len - index;
        if (numMoved == 0)
            newElements = Arrays.copyOf(es, len + 1);
        else {
            newElements = new Object[len + 1];
            System.arraycopy(es, 0, newElements, 0, index);
            System.arraycopy(es, index, newElements, index + 1,
                             numMoved);
        }
        newElements[index] = element;
        setArray(newElements);
    }
}

// set方法，同理
public E set(int index, E element) {
    synchronized (lock) { // 修改前加锁
        Object[] es = getArray();
        E oldValue = elementAt(es, index);

        if (oldValue != element) {
            es = es.clone(); // 创建副本
            es[index] = element;
            setArray(es);
        }
        return oldValue;
    }
}

// 删除方法同理
public E remove(int index) {
    synchronized (lock) {
        Object[] es = getArray();
        int len = es.length;
        E oldValue = elementAt(es, index);
        int numMoved = len - index - 1;
        Object[] newElements;
        if (numMoved == 0)
            newElements = Arrays.copyOf(es, len - 1);
        else {
            newElements = new Object[len - 1];
            System.arraycopy(es, 0, newElements, 0, index);
            System.arraycopy(es, index + 1, newElements, index,
                             numMoved);
        }
        setArray(newElements);
        return oldValue;
    }
}
```



**COWIterator 迭代器**

我们知道每一个集合都拥有迭代器，CopyOnWriteArrayList采用COWIterator迭代器，它是通过使用当前数组的快照实现，也就是说对并发写不敏感。

```java
static final class COWIterator<E> implements ListIterator<E> {
    
        private final Object[] snapshot; // 当前列表的快照对象
        private int cursor; //迭代器的游标

        COWIterator(Object[] es, int initialCursor) {
            cursor = initialCursor;
            snapshot = es;
        }

        public boolean hasNext() {
            return cursor < snapshot.length;
        }

        public boolean hasPrevious() {
            return cursor > 0;
        }

        @SuppressWarnings("unchecked")
        public E next() {
            if (! hasNext())
                throw new NoSuchElementException();
            return (E) snapshot[cursor++];
        }

        @SuppressWarnings("unchecked")
        public E previous() {
            if (! hasPrevious())
                throw new NoSuchElementException();
            return (E) snapshot[--cursor];
        }

        public int nextIndex() {
            return cursor;
        }

        public int previousIndex() {
            return cursor - 1;
        }

    	// 不支持remove 、 set 、 add方法
        public void remove() {
            throw new UnsupportedOperationException();
        }

        public void set(E e) {
            throw new UnsupportedOperationException();
        }

        public void add(E e) {
            throw new UnsupportedOperationException();
        }

    	// lambda方法的实现
        @Override
        public void forEachRemaining(Consumer<? super E> action) {
            Objects.requireNonNull(action);
            final int size = snapshot.length;
            int i = cursor;
            cursor = size;
            for (; i < size; i++)
                action.accept(elementAt(snapshot, i));
        }
    }
```

