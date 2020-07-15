---
title: Java源码——ArrayList
date: 2020-5-1
tags: [源码]
---
{% asset_img image1.jpg 算法 %}

# ArrayList
<!--more-->

**ArrayList和LinkedList**

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;ArrayList和LinkedList是List接口的重要实现类，也是开发中最常用到的线性表和链表数据结构。ArrayList底层采用数组结构，而LinkedList底层采用Entry节点和指针的链表结构，两者主要性能区别：

- 查询性能ArrayList更高
- 中间插入和删除数据LinkedList效率更高

<font color=red>总结：</font>

1. ArrayList底层使用数组结构，数据检索能力更高，默认初始容量10。
2. 当size==length时触发扩容，每次扩容为1.5倍，扩容时旧数组和新数组并存，在GC之前占用两份空间，大数据量会不断扩容导致性能问题，**一般建议评估保存数据的容量并赋初始值，如`new ArrayList(10000)`**。
3. 实现了RandomAccess接口，在使用Collections进行二分查找binarySearch时，会使用索引查找，效率更高。
4. 非线程安全，并发修改和查找会影响modCount不匹配，导致快速抛出ConcurrentModificationException异常。
5. clone方法属于浅克隆shallow clone。
6. SubList是ArrayList在使用subList方法时的返回内部类，它同样继承自AbstracList但会共享当前ArrayList实例的数组，对SubList的修改其实是对原始数据的修改，**一般建议，如果希望subList作为独立副本使用，使用Arrays.copyOf创建**。
7. Arrays.asList方法返回的是Arrays的内部类ArrayList，区别于List中的ArrayList类，虽然同名但只提供了少量的功能，切不可作为后者进行数据处理，否则有NoSuchMethodException风险，**一般建议，如果希望作为线性表List接口中的ArrayList，采用以下方式:**`List dupList = new Array(Arrays.asList("abc", "def", "ghi"))`。

**成员变量**

```java
// 默认容量
private static final int DEFAULT_CAPACITY = 10; 
private static final Object[] EMPTY_ELEMENTDATA = new Object[0];
private static final Object[] DEFAULTCAPACITY_EMPTY_ELEMENTDATA = new Object[0];
// 实际存储数组
transient Object[] elementData;
private int size; // size是已存数据容量，length是数组容量，一般size <= length
private static final int MAX_ARRAY_SIZE = 2147483639;
```



**add方法和扩容**

```java
// 在数组末尾新增数据，当前数组size==length时触发扩容方法this.grow
private void add(E e, Object[] elementData, int s) {
    if (s == elementData.length) {
        elementData = this.grow();
    }

    elementData[s] = e;
    this.size = s + 1;
}

public boolean add(E e) {
    ++this.modCount;
    this.add(e, this.elementData, this.size);
    return true;
}
```

```java
// Arrays.copyOf使用System.arrayCopy本地方法将原数组数据移植到新容量数组中
private Object[] grow(int minCapacity) {
    return this.elementData = Arrays.copyOf(this.elementData, this.newCapacity(minCapacity));
}

private Object[] grow() {
    return this.grow(this.size + 1);
}

// 如果需要扩容，则会扩大为原来容量的1.5倍
private int newCapacity(int minCapacity) {
    int oldCapacity = this.elementData.length;
    int newCapacity = oldCapacity + (oldCapacity >> 1); // aka 1.5倍
    if (newCapacity - minCapacity <= 0) {
        if (this.elementData == DEFAULTCAPACITY_EMPTY_ELEMENTDATA) {
            return Math.max(10, minCapacity);
        } else if (minCapacity < 0) {
            throw new OutOfMemoryError();
        } else {
            return minCapacity;
        }
    } else {
        return newCapacity - 2147483639 <= 0 ? newCapacity : hugeCapacity(minCapacity);
    }
}
```



**浅克隆**

```java
// 浅克隆并重置modCount=0
public Object clone() {
    try {
        ArrayList<?> v = (ArrayList)super.clone();
        v.elementData = Arrays.copyOf(this.elementData, this.size);
        v.modCount = 0;
        return v;
    } catch (CloneNotSupportedException var2) {
        throw new InternalError(var2);
    }
}
```



**实现RandomAccess接口**

```java
// List接口只有ArrayList实现了RandomAccess声明式接口
// 其目的是在使用Collections.binarySearch二分查找方法时采用索引遍历而非迭代器遍历
public class ArrayList<E> extends AbstractList<E> implements List<E>, RandomAccess, Cloneable, Serializable {...}
```

```java
// Collections方法类
// List实现了RandomAccess直接使用indexBinarySearch方法，该方法执行效率高于iteratorBinarySearch方法。
public static <T> int binarySearch(List<? extends Comparable<? super T>> list, T key) {
        return !(list instanceof RandomAccess) && list.size() >= 5000 ? iteratorBinarySearch(list, key) : indexedBinarySearch(list, key);
    }
```



**modCount**

当数组进行了增删改操作，modCount会自增，这是为了保证在并发访问和操作时保证线性表数据统一，否则会抛出ConcurrentModificationException异常，抛出异常的目的是快速反馈给调用者以发现并发问题并采取有效的措施。

```java
public boolean add(E e) {
    ++this.modCount;
    this.add(e, this.elementData, this.size);
    return true;
}

public void clear() {
    ++this.modCount;
    Object[] es = this.elementData;
    int to = this.size;

    for(int i = this.size = 0; i < to; ++i) {
        es[i] = null;
    }

}
private void fastRemove(Object[] es, int i) {
    ++this.modCount;
    int newSize;
    if ((newSize = this.size - 1) > i) {
        System.arraycopy(es, i + 1, es, i, newSize - i);
    }

    es[this.size = newSize] = null;
}

public void sort(Comparator<? super E> c) {
    int expectedModCount = this.modCount;
    Arrays.sort(this.elementData, 0, this.size, c);
    // 如果不相等则抛出异常
    if (this.modCount != expectedModCount) {
        throw new ConcurrentModificationException();
    } else {
        ++this.modCount;
    }
}
```



**subList方法和SubList内部类**

```java
// subList方法返回ArrayList内部类SubList
public List<E> subList(int fromIndex, int toIndex) {
    subListRangeCheck(fromIndex, toIndex, this.size);
    return new ArrayList.SubList(this, fromIndex, toIndex);
}
```

```java
// 同样实现AbstractList抽象类与父类ArrayList相同
private static class SubList<E> extends AbstractList<E> implements RandomAccess {
    private final ArrayList<E> root;
    private final ArrayList.SubList<E> parent;
    private final int offset;
    private int size;
    ...
    // 没有trimToSize()方法
    // 共享修改父类
    public E set(int index, E element) {
        Objects.checkIndex(index, this.size);
        this.checkForComodification();
        E oldValue = this.root.elementData(this.offset + index);
        this.root.elementData[this.offset + index] = element;
        return oldValue;
    }
    ...
}
```

```java
// 当采用如下用法将抛出NoSuchMethodException异常
List mainList = new ArrayList(Arrays.asList(1,2,3,4,5));
List subList = mainList.subList(0,2);
subList.trimToSize(); // NoSuchMethodException

// 当想当然的以为对subList修改时，mainList也被修改
subList.set(0, 10);
print(mainList); // 10,2,3,4,5
print(subList); // 10,2

// 可以采取如下措施避免subList问题
List dupSubList = new ArrayList(subList);
dupSubList.set(0, 10);
System.out.println(mainList); // 1,2,3,4,5
System.out.println(subList); // 1,2
System.out.println(dupSubList); // 10,2
```



**Arrays.asList和Arrays内部类ArraysList**

```java
public class Arrays {
...
    // 作为内部类虽然与ArrayList同名，但只有部分方法，容易产生NoSuchMethodException异常
    private static class ArrayList<E> extends AbstractList<E> implements RandomAccess, Serializable {...}    
}

```

```java
List list = Arrays.asList(1,2,3,4,5)
list.trimToSize(); // NoSuchMethodException

// 采取如下措施转换为ArraysList
List _list = new Array(list);
_list.trimToSize();
```

