---
title: Java源码——LinkedList
date: 2020-5-5
tags: [源码]
---
{% asset_img image1.jpg 算法 %}

# LinkedList
<!--more-->

(version: JDK 11)

<font color=red>总结：</font>

1. LinkedList底层采用双向列表数据结构。
2. 载JDK11中包含两个指针成员变量first和last分别指向链表的首位和末位，JDK7采用单指针header，末位对象指向header，也就是说header的后继next指向链表第一个节点，header的前驱previous指向链表最后一个节点。LinkedList实现前驱指针目的是为了实现单向队列和双端队列数据结构。源码以jdk11为例。

**成员变量**

```java
transient int size;
transient LinkedList.Node<E> first;
transient LinkedList.Node<E> last;
private static final long serialVersionUID = 876323262645176354L;
```



**节点对象**

```java

private static class Node<E> {
    E item;	// 元素
    LinkedList.Node<E> next; // 后继
    LinkedList.Node<E> prev; // 前驱

    Node(LinkedList.Node<E> prev, E element, LinkedList.Node<E> next) {
        this.item = element;
        this.next = next;
        this.prev = prev;
    }
}
```

**add方法**

```java
public boolean add(E e) {
    this.linkLast(e);
    return true;
}

void linkLast(E e) {
    LinkedList.Node<E> l = this.last;
    LinkedList.Node<E> newNode = new LinkedList.Node(l, e, (LinkedList.Node)null);
    this.last = newNode;
    if (l == null) {
        this.first = newNode; // 链表为空则指向对一个节点
    } else {
        l.next = newNode;	// 链表不为空则指向末尾节点
    }

    ++this.size;
    ++this.modCount;
}
```



**get方法**

```java
public E get(int index) {
    this.checkElementIndex(index); // 索引越界检查
    return this.node(index).item; // 返回节点的元素
}

private void checkElementIndex(int index) {
    if (!this.isElementIndex(index)) {
        throw new IndexOutOfBoundsException(this.outOfBoundsMsg(index));
    }
}

private boolean isElementIndex(int index) {
    return index >= 0 && index < this.size;
}

// 因为指针遍历较慢，所以对链表从中间截取判断index落位上半位还是下半位
LinkedList.Node<E> node(int index) {
    LinkedList.Node x;
    int i;
    if (index < this.size >> 1) { // 上半位，从first节点查找
        x = this.first;

        for(i = 0; i < index; ++i) { 
            x = x.next;
        }

        return x;
    } else { //下半位，从last节点查找
        x = this.last;

        for(i = this.size - 1; i > index; --i) {
            x = x.prev;
        }

        return x;
    }
}
```



**浅克隆**

```java
// 浅克隆并重置modCount=0
public Object clone() {
    LinkedList<E> clone = this.superClone();
    clone.first = clone.last = null;
    clone.size = 0;
    clone.modCount = 0;

    for(LinkedList.Node x = this.first; x != null; x = x.next) {
        clone.add(x.item);
    }

    return clone;
}

private LinkedList<E> superClone() {
    try {
        return (LinkedList)super.clone();
    } catch (CloneNotSupportedException var2) {
        throw new InternalError(var2);
    }
}
```



**modCount**

与ArrayList一样，当链表进行了增删改操作，modCount会自增，这是为了保证在并发访问和操作时保证链表数据统一，否则抛出ConcurrentModificationException异常，抛出异常的目的是快速反馈给调用者以发现并发问题并采取有效的措施。

```java
final void checkForComodification() {
    if (LinkedList.this.modCount != this.expectedModCount) {
        throw new ConcurrentModificationException();
    }
}
```



**队列实现方法**

队列属于基础数据结构，采用FIFO先进先出原则，这就要求具有首位获得数据和末位添加数据的能力。

```java
// 返回头结点元素，不删除，为空则返回null
public E peek() {
    LinkedList.Node<E> f = this.first;
    return f == null ? null : f.item;
}

// 返回头结点元素，不删除，为空则抛出异常
public E element() {
    return this.getFirst();
}

public E getFirst() {
    LinkedList.Node<E> f = this.first;
    if (f == null) {
        throw new NoSuchElementException();
    } else {
        return f.item;
    }
}

// 返回头结点元素，删除，为空则返回null
public E poll() {
    LinkedList.Node<E> f = this.first;
    return f == null ? null : this.unlinkFirst(f);
}

// 返回头结点元素，删除，为空则抛出异常
public E remove() {
    return this.removeFirst();
}

// 末位添加元素
public boolean offer(E e) {
    return this.add(e);
}

// 返回头结点元素，删除，为空则抛出异常
public E pop() {
    return this.removeFirst();
}
```

**双端队列实现方法**

双端队列是队列的变形，支持头结点和尾节点的添加元素和获得元素。

与链表类似使用的方法则不在额外说明。

```java
// 头结点前驱添加元素
public void push(E e) {
    this.addFirst(e);
}

public E pop() {
    return this.removeFirst();
}

public E peekFirst() {
    LinkedList.Node<E> f = this.first;
    return f == null ? null : f.item;
}

public E peekLast() {
    LinkedList.Node<E> l = this.last;
    return l == null ? null : l.item;
}

public E removeFirst() {
    LinkedList.Node<E> f = this.first;
    if (f == null) {
        throw new NoSuchElementException();
    } else {
        return this.unlinkFirst(f);
    }
}

public E removeLast() {
    LinkedList.Node<E> l = this.last;
    if (l == null) {
        throw new NoSuchElementException();
    } else {
        return this.unlinkLast(l);
    }
}

public E pollFirst() {
    LinkedList.Node<E> f = this.first;
    return f == null ? null : this.unlinkFirst(f);
}

public E pollLast() {
    LinkedList.Node<E> l = this.last;
    return l == null ? null : this.unlinkLast(l);
}

public boolean offerFirst(E e) {
    this.addFirst(e);
    return true;
}

public boolean offerLast(E e) {
    this.addLast(e);
    return true;
}

```

