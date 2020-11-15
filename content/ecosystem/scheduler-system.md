## 演进

在 Google 的一篇关于 Omega 的调度系统的论文，把调度系统分成几类：中心化调度框架、两级调度框架、共享状态调度框架、全分布式框架。

通常 Google 的 Borg 被分到单体这一类，Mesos 被分到两级调度框架，而 Google 自己的 Omega 被分到共享状态。
论文的作者实际上之前也是 Mesos 的设计者之一，后来去了 Google 设计新的 Omega 系统，并发表了论文，论文的主要目的是提出一种全新的"Shard State"的模式来同时解决调度系统的性能和扩展性的问题，但是实际"Shared State"模型太过理想化，根据这个模型开发的 Omega 系统，似乎在 Google 内部并没有被大规模使用，也没有任何一个大规模使用的调度系统采是采用 Shared State 模型。

![images](http://70data.net/upload/kubernetes/1_WHlcQ3YuTxsZlP1seEQHcQ.png)

![images](http://70data.net/upload/kubernetes/WechatIMG1883.jpeg)

### 中心化调度框架

单一的调度进程在一台机器上运行，调度器负责将任务指派给集群内的机器。
在中心化调度框架下，所有的工作负载都是由一个调度器来处理，所有的作业都通过相同的调度逻辑来处理。
这种架构很简单并且统一，在这个基础上发展出了许多复杂的调度器。比如 Paragon 调度器和 Quasar 调度器，它们使用机器学习的方法来避免负载之间因互相竞争资源而产生的干扰。

- 因为不同的应用有不同的需求，若要全部满足其需求则需要不断在调度器中增加特性，这样增加了它的逻辑复杂度和部署难度。
- 调度器处理作业的顺序变成了一个问题，队列效应和作业积压是一个问题，除非在设计调度器时非常小心。

### 两级调度框架

两级调度允许根据特定的应用来定做不同的作业调度逻辑，并同时保留了不同作业之间共享集群资源的特性。

- 高优先级抢占会变得很难实现。
- 调度器无法考虑到因其他运行的工作负载造成的干扰可能影响到资源的质量（比如"吵闹的邻居"占据了 I/O 带宽）。
- offer/request 接口很容易变得非常复杂。因为应用特定的调度器对底层资源的很多不同方面很关心，它们获得资源的唯一方法就是通过资源管理器提供的接口。

### 共享状态调度框架

共享状态调度通过半分布式的模式来实现调度，在这种模式下应用层的每个调度器都拥有一份集群状态的副本，并且调度器会独立地对集群状态副本进行更新。
一旦本地的状态副本产生了变化，调度器会发布一个事务去更新整个集群的状态，有时候因另外一个调度器同时发布了一个冲突的事务时，事务更新有可能失败。

除了 Google 的 Omega，还有 Microsoft 的 Apollo、Hashicorp 的 Nomad。 
所有的这些都是使用一种方法实现共享状态调度，就是 Omega 中的 "cell state"、Apollo 的 "resource monitor" 以及 Nomad 中的 "plan queue"。
Apollo 跟其他两个调度框架不同之处在于其共享状态是只读的，调度事务是直接提交到集群中的机器上，机器自己会检查冲突，来决定是接受还是拒绝这个变化，这使得 Apollo 即使在共享状态暂时不可用的情况下也可以执行。

逻辑上的共享状态调度架构也可以不通过将整个集群的状态分布在其他地方来实现。
这种方式中，每台机器维护其自己的状态并发送更新的请求到其他对该节点感兴趣的代理，比如调度器、设备健康监控器和资源监控系统等。每个物理设备的本地状态都成为了整个集群的共享状态的分片之一。

共享状态调度框架必须工作在有稳定信息的情况下，在集群资源的竞争度很高的情况下有可能造成调度器的性能下降。

### 全分布式框架

全分布式架构更加去中心化，调度器之间根本没有任何的协调，并且使用很多各自独立的调度器来处理不同的负载。每个调度器都作用在自己本地的集群状态信息。
在分布式调度架构下，作业可以提交给任意的调度器，并且每个调度器可以将作业发送到集群中任何的节点上执行。
与两级调度调度框架不同的是，每个调度器并没有负责的分区，相反的是，全局调度和资源划分都是服从统计和随机分布的，与共享状态调度架构有些相似，但是没有中央控制。

现代意义上的分布式调度应该是从 Sparrow 论文开始的。
Sparrow 论文的关键是它假设集群上任务周期都会变的越来越短，这点是以当时一个讨论作为支撑的"细粒度的任务有很多的优势"。因此假设作业会变得越来越多。
这意味着调度器必须支持更高决策的吞吐量，而单一的调度器并不能支持如此高的吞吐量，因此 Sparrow 将这些负载分散到很多调度器上。

分布式调度器是基于简单的"slot"概念，将每台机器分成 n 个标准的"slot"，并放置 n 个并行作业，这简化了任务的资源需求不统一的事实。

- 调度器不够灵活。它使用了拥有简单服务规则的 worker-side 队列，调度器只能选择将作业放置在哪台设备的队列上。
- 很难执行全局不变量，例如公平策略和严格优先级，因为它没有中央控制。
- 无法支持或承担复杂或特定应用的调度策略。分布式调度是基于最少知识做出快速决策而设计的。

### 混合式调度框架

混合式调度框架是最近学术界提出的提出的解决方法，它的出现是为了解决全分布式框架的缺点，它结合了中心化调度和共享状态的设计。
Tarcil、Mercury、Hawk 一般有两条调度路径。一条是为部分负载设计的分布式调度，另外一条是中心式作业调度来处理剩下的负载。

## MapReduce v1

![images](http://70data.net/upload/scheduler/MRv1.webp)

- Job Tracker 是集群主要的管理组件，同时承担了资源调度和任务调度的责任。
- Task Tracker 运行在集群的每一台机器上，负责在主机上运行具体的任务，并且汇报状态。

问题：
- 资源利用率比较低。MapReduce v1 给每个节点静态配置了固定数目的 Slot，每个 Slot 也只能够运行的特定的任务的类型，这就导致资源利用率有问题。比如大量 Map 任务在排队等待空闲资源，但实际上机器有大量 Reduce 的 Slot 被闲置。
- 性能有一定瓶颈。支持管理的最大节点数是 5 千个节点，支持运行的任务最大数量 4 万。
- 多租户和多版本的问题。
- 不够灵活，无法扩展支持其他任务类型。

## Yarn

![images](http://70data.net/upload/scheduler/YARN.webp)

- Resource Manager 承担资源调度的职责，管理所有资源，将资源分配给不同类型的任务，并且通过"可插拔"的架构来很容易的扩展资源调度算法。
- Application Master 承担任务调度的职责，每一个作业都会启动一个对应的 Application Master，它来负责把作业拆分成具体的任务，向 Resource Manager 申请资源、启动任务、跟踪任务的状态并且汇报结果。

引入了容器隔离技术，每一个任务都是在一个隔离的容器里面运行，根据任务对资源的需求来动态分配资源，大幅提高了资源利用率。
任务调度的组件 Application Master 和资源调度解耦，而且是根据作业的请求而动态创建的，一个 Application Master 实例只负责一个作业的调度，也就更加容易支持不同类型的作业。
将原来的 Job Tracker 的任务调度职责拆分出来，大幅度提高了性能。原来的 Job Tracker 的任务调度的职责拆分出来由 Application Master 承担，并且 Application Master 是分布式的，每一个实例只处理一个作业的请求，将原来能够支撑的集群节点最大数量，从原来的 5 千节点提升到 1 万节点。

问题：
- Resource Manager 提供资源的方式是被动的，当资源的消费者（Application Master) 需要资源的时候，会调用 Resource Manager 的接口来获取到资源，Resource Manager 只是被动的响应 Application Master 的需求。决定权在于 Yarn 本身。
- Resource Manager 负责所有应用的任务调度，各个应用作为 Yarn 的一个 client library。传统应用，接入比较困难。
- Yarn 的资源管理和分配，只有内存一个维度。 

## Mesos

![images](http://70data.net/upload/scheduler/Mesos.webp)

- Mesos Master 单纯是承担资源分配和管理的组件，的对应到 Yarn 里面就是那个 Resource Manager，不过工作方式会稍微有些不太一样。
- Framework 承担作业调度，不同的作业类型都会有一个对应的 Framework。

Mesos 中将资源调度的过程分成了 2 个阶段：资源 —> Offer —> 任务匹配。Mesos Master 只负责完成第一个阶段，第二个阶段的匹配交给 Framework 来完成。性能明显提高。根据模拟测试一个集群最大可以支撑 10 万个节点。
Mesos 更 scalable。
Mesos 可以同时支持短类型任务以及长类型服务。

Mesos 中的 Master 会定期的主动推送当前的所有可用的资源，就是所谓的 Resource Offer 给 Framework。
Framework 如果有任务需要被执行，不能主动申请资源，只有当接收到 Offer 的时候，从 Offer 里面挑选满足要求的资源来接受，在 Mesos 里面这个动作叫做 Accept，剩余的 Offer 就都拒绝掉，这个动作叫做 Reject，如果这一轮 Offer 里面没有足够能够满足要求的资源，只能等待下一轮 Master 提供 Offer。
当 Framework 长期拒绝资源，Mesos 将跳过该 Framework，将资源提供给其他 Framework。

Mesos 中的 DRF 调度算法过分的追求公平，没有考虑到实际的应用需求。
在实际生产线上，往往需要类似于 Hadoop 中 Capacity Scheduler 的调度机制，将所有资源分成若干个 queue，每个 queue 分配一定量的资源，每个 user 有一定的资源使用上限。使用的调度策略是应该支持每个 queue 可单独定制自己的调度器策略，比如 FIFO、Priority 等。

DRF 是 min-max fairness 算法的一个变形，简单来说就是每次都挑选支配资源占用率最低的那个 Framework 提供 Offer。

计算 Framework 的"支配资源占用率"。
从 Framework 占用的所有资源类型里面，挑选资源占用率最小的那个资源类型做为支配资源。它的资源占用率就是这个 Framework 的支配资源占用率。
一个 Framework X 的 CPU 占用了整体资源的 20%，内存是 30%，磁盘是 10%，那么这个 Framework 的支配资源占用率就是 10%

DRF 的最终目的是把资源平均的分配给所有 Framework，如果一个 Framework X 在这一轮 Offer 中接受了过多的资源，那么就要等更长的时间才能获得下一轮 Offer 的机会。

这个算法里面有一个假设，就是 Framework 接受了资源之后，会很快释放掉，否则就会有 2 个后果：
- 其他 Framework 被"饿死"。某个 Framework A 一次性的接受了集群中大部分资源，并且任务一直运行不退出，这样大部分资源就被 Framework A 一直霸占了，其他 Framework 就没法获得资源了。
- 自己被饿死。因为这个 Framework 的支配资源占用率一直很高，所以长期无法获得 Offer 的机会，也就没法运行更多的任务。

问题：
- Mesos 提供资源的方式是主动的。Mesos 本身并不知道各个应用程序资源需求，为了一致性，Master 一次只能给一个 Framework 提供 Offer，等待这个 Framework 挑选完 Offer 之后，再把剩余的提供给下一个 Framework。所以会出现有资源需求的 Framework 在排队等待 Offer，但是没有资源需求的 Framework 却频繁收到 Offer 的情况。任何一个 Framework 做决策的效率就会影响整体的效率。
- 资源碎片。每个节点上的资源不可能全部被分配完，剩下的一点可能不足以让任何任务运行，这样便产生了类似于操作系统中的内存碎片问题。
- Mesos 只适合调度短任务，Mesos 在设计之初就是为数据中心中的段任务而设计的。
- 资源分配粒度粗，比较适合多种计算框架并存的现状。

## 对比

资源利用率 Kubernetes 胜出。
理论上 Kubernetes 应该能实现更加高效的集群资源利用率，原因资源调度的职责完全是由 Scheduler 一个组件来完成的，它有充足的信息能够从全局来调配资源。
Mesos 却做不到，因为资源调度的职责被切分到 Framework 和 Mesos Master 两个组件上，Framework 在挑选 Offer 的时候，完全没有其他 Framework 的工作负载的信息，所以也不可能做出最优的决策。

扩展性 Mesos 胜出。
从理论上讲 Mesos 的扩展性要更好一点。原因是 Mesos 的资源调度方式更容易让已经存在的任务调度迁移上来。

灵活的任务调度策略 Mesos 胜出。
Mesos 对各种任务的调度策略也要支持的更好。

性能 Mesos 胜出。
Mesos 的性能更好，因为资源调度组件，也就是 Mesos Master 把一部分资源调度的工作甩给 Framework了，承担的调度工作更加简单。

调度延迟 Kubernetes 胜出。
Kubernetes 调度延迟会更好。因为 Mesos 的轮流给 Framework 提供 Offer 机制，导致会浪费很多时间在给不需要资源的 Framework 提供 Offer。 

## CapOS

CapOS 是 Hulu 内部的一个大规模分布式任务调度和运行平台。

![images](http://70data.net/upload/kubernetes/m7sHtv6XiciaLuMse3A.webp)

CapScheduler 是一个基于 Mesos 的 Scheduler，负责任务的接收，元数据的管理，任务调度。
CapExecutor 是 Mesos 的一个 customized executor，实现 pod-like 的逻辑，以及 pure container resource 的功能。

![images](http://70data.net/upload/kubernetes/zL2ETd59vibKMLzkhg.webp)

![images](http://70data.net/upload/kubernetes/1gnZsIpKT3h9fOr9g.webp)

缓存 offer。
当 scheduler 从 Mesos 中获取 offer 时候，CapScheduler会把 offer 放入到 cache，offer 在 TTL 后，offer 会被 launch 或者归还给 Mesos。
这样可以和作业的 offer 的置放策略解耦。

插件化的调度策略。
CapScheduler 会提供一系列的可插拔的过滤函数和优先级函数，这些优先级函数对 offer 进行打分，作用于调度策略。
用户在提交作业的时候，可以组合过滤函数和优先级函数，来满足不同 workload 的调度需求。

延迟调度。
当一个作业选定好一个 offer 后，这个 offer 不会马上被 launch，CapScheduler 会延迟调度，以期在一个 offer 中 match 更多作业后，再 launch offer。获取更高的作业调度吞吐。

1. 根据过滤函数进行 offer 过滤，比如 constraints。
2. apply 所有的优先级打分函数进行打分。打分的时候会根据一个请求和 offer 的资源，算 cpu 和 mem 的比例，选取出 dominate 的 resource 进行主要评分。
3. 选取最优的 offer 进行 bind。
4. bind 之后不会马上调度，而是会 delay scheduler。在比较繁忙的情况下，一次 offer launch 可以启动多个 tasks，这是对于大规模吞吐的考虑。

