/* ============================================================
   js/science-tips.js —— 全站化学 / 物理小知识
   ------------------------------------------------------------
   站长要求：写点化学和物理的 Tips，出现在全站各个地方。

   做法：每个页面刷新时随机抽一条，显示在页脚上方。
        不改各页面的 HTML 结构，脚本自己找位置插进去。

   加词：直接往 TIPS 数组里加就行，格式 ["分类", "内容"]。
   ============================================================ */
(function () {
    'use strict';

    var TIPS = [
        /* ==================== 化学 · 生活冷知识 ==================== */
        ["化学 · 生活", "切开的苹果放久会变褐，是酚类物质被氧化了。滴点柠檬汁能延缓。"],
        ["化学 · 生活", "铁锅洗完不擦干会生锈，因为铁在潮湿空气里会形成原电池，加速腐蚀。"],
        ["化学 · 生活", "煮鸡蛋时蛋黄表面发绿，是蛋清里的硫和蛋黄里的铁生成了硫化铁，无害。"],
        ["化学 · 生活", "自来水有氯味是消毒残留。烧开后敞盖再煮 1~2 分钟就能挥发掉。"],
        ["化学 · 生活", "小苏打能除冰箱异味，靠的是它吸附酸性气味分子。"],
        ["化学 · 生活", "紫甘蓝汁可以做酸碱指示剂：遇酸变红，遇碱变绿，中性是紫色。"],
        ["化学 · 生活", "铝锅不能长时间装咸菜，盐会破坏铝表面的氧化膜。"],
        ["化学 · 生活", "铜器发绿是生成了碱式碳酸铜，也就是常说的「铜绿」。"],
        ["化学 · 生活", "蚊虫叮咬后涂肥皂水能止痒，因为蚁酸被碱中和了。"],
        ["化学 · 生活", "硬水洗手不容易起泡，是钙镁离子在和肥皂反应。"],
        ["化学 · 生活", "蛋糕里加小苏打会蓬松，是受热分解产生了二氧化碳。"],
        ["化学 · 生活", "干冰不是冰，是固态二氧化碳，会直接升华成气体，不留水渍。"],
        ["化学 · 生活", "冬天路面撒盐化雪，是因为盐水的凝固点比纯水低。"],
        ["化学 · 生活", "银饰发黑是生成了硫化银，用牙膏擦能去掉，但会磨掉一点点银。"],
        ["化学 · 生活", "煤气本身无色无味，能闻到味是因为特意加了硫醇做警示剂。"],
        ["化学 · 生活", "不锈钢不容易生锈，是铬在表面形成了致密的氧化膜。"],
        ["化学 · 生活", "汽水开盖冒泡，是压强降低后二氧化碳的溶解度下降。"],
        ["化学 · 生活", "牛奶加热结皮，是蛋白质受热变性凝固。"],
        ["化学 · 安全", "84 消毒液和洁厕灵绝对不能混用，会产生氯气。"],
        ["化学 · 生活", "酒精能消毒是因为它使蛋白质变性，不是简单的「杀菌」。"],
        ["化学 · 生活", "75% 酒精比 95% 效果好，因为浓度太高会让细菌表面蛋白过快凝固，反而进不去。"],
        ["化学 · 原理", "铅笔芯和金刚石都是碳，只是原子的排列方式不同。"],
        ["化学 · 原理", "石墨能导电而金刚石不能，因为石墨是层状结构，层间有自由电子。"],
        ["化学 · 生活", "味精的主要成分是谷氨酸钠，正常食用量对人体无害。"],
        ["化学 · 生活", "蜂蜜放久会结晶，是葡萄糖析出，不是变质。"],
        ["化学 · 生活", "菜刀用完要擦干再涂一层油，隔绝水和氧气。"],
        ["化学 · 生活", "面包放冰箱反而更容易变干，淀粉在低温下会老化回生。"],
        ["化学 · 生活", "汽水里加薄荷糖会喷涌，是粗糙表面提供了大量成核位点。"],
        ["化学 · 安全", "湿手不能碰电器开关，因为水里的杂质让水成了导体。"],
        ["化学 · 生活", "一次性饭盒不能进微波炉，除非标了「微波炉适用」。"],
        ["化学 · 生活", "削好的土豆泡水里能防变黑，是隔绝了氧气。"],
        ["化学 · 生活", "茶叶水放久颜色变深，是茶多酚被氧化成了茶褐素。"],
        ["化学 · 生活", "紫药水、碘酒不能和红药水一起用，会产生碘化汞。"],
        ["化学 · 生活", "面团发酵变大，是酵母产生的二氧化碳被面筋兜住了。"],
        ["化学 · 生活", "皮蛋的味道来自碱性物质渗入，蛋白在碱性条件下变性成了凝胶。"],
        ["化学 · 生活", "油锅着火不能用水浇，水会瞬间汽化把燃烧的油溅开。"],
        ["化学 · 生活", "暖宝宝发热靠铁的缓慢氧化，不是燃烧但确实在放热。"],
        ["化学 · 生活", "碳酸饮料加盐会剧烈冒泡，是盐提供了更多成核位点。"],
        ["化学 · 生活", "新买的衣服先洗一遍，能去掉残留的甲醛和染料。"],
        ["化学 · 生活", "花露水能驱蚊，靠的是避蚊胺或驱蚊酯，不是香味。"],
        ["化学 · 生活", "空调房放盆水有意义，蒸发能提高一点空气湿度。"],
        ["化学 · 生活", "铅笔写的字能用橡皮擦掉，是石墨层被黏土粘走了。"],
        ["化学 · 生活", "水垢的主要成分是碳酸钙和氢氧化镁，用醋能溶解。"],
        ["化学 · 生活", "豆腐和菠菜一起煮会有涩味，是草酸和钙生成了草酸钙。"],
        ["化学 · 生活", "维生素 C 能防水果变褐，因为它自己先被氧化了。"],
        ["化学 · 生活", "铝箔不能包酸性食物，酸会溶解氧化膜让铝进入食物。"],
        ["化学 · 生活", "盐水漱口能缓解咽喉痛，靠的是高渗环境让细菌失水。"],
        ["化学 · 生活", "火柴盒侧面那层是红磷，划动摩擦生热让它点燃。"],
        ["化学 · 生活", "肥皂水遇硬水会起浮渣，是钙镁离子和脂肪酸生成了沉淀。"],
        ["化学 · 生活", "樟脑丸变小是升华，不是熔化——它直接从固态变成气体。"],

        /* ==================== 化学 · 原理与规律 ==================== */
        ["化学 · 原理", "空气中氮气约占 78%，氧气约占 21%，其余 1% 是稀有气体和二氧化碳。"],
        ["化学 · 原理", "纯水在 25℃ 时 pH 是 7，但暴露在空气里会慢慢变酸——溶解了二氧化碳。"],
        ["化学 · 原理", "催化剂只加快反应速率，不改变反应的最终平衡位置。"],
        ["化学 · 原理", "勒夏特列原理：改变条件时，平衡会朝「削弱这个改变」的方向移动。"],
        ["化学 · 原理", "同素异形体：同种元素的不同单质，比如氧气和臭氧、金刚石和石墨。"],
        ["化学 · 原理", "同位素：质子数相同、中子数不同，化学性质几乎一样。"],
        ["化学 · 原理", "焰色反应：钠是黄色，钾是紫色（要透过蓝色钴玻璃看），钙是砖红色，铜是绿色。"],
        ["化学 · 原理", "分子在不停运动，温度越高运动越快——这就是扩散现象的本质。"],
        ["化学 · 原理", "分子之间有间隙，所以 50mL 水和 50mL 酒精混合后小于 100mL。"],
        ["化学 · 原理", "布朗运动是花粉微粒被水分子撞击的表现，它证明了分子的无规则运动。"],
        ["化学 · 原理", "化学反应的实质是原子重新组合，原子本身不变。"],
        ["化学 · 原理", "质量守恒定律：反应前后原子种类和数目都不变，所以质量不变。"],
        ["化学 · 原理", "氧化反应不一定要有氧气参与，失去电子的过程都是氧化。"],
        ["化学 · 口诀", "钾钙钠镁铝，锌铁锡铅氢，铜汞银铂金——金属活动性顺序，越靠前越活泼。"],
        ["化学 · 原理", "排在氢前面的金属能置换出酸里的氢，后面的不能。"],
        ["化学 · 安全", "浓硫酸稀释必须把酸倒进水里，不能反过来——否则会剧烈放热飞溅。"],
        ["化学 · 原理", "复分解反应发生的条件：生成沉淀、气体或水。"],
        ["化学 · 原理", "溶液不一定是无色的，硫酸铜溶液是蓝色，高锰酸钾溶液是紫红色。"],
        ["化学 · 原理", "饱和溶液降温不一定析出晶体，要看溶解度随温度怎么变。"],
        ["化学 · 原理", "气体的溶解度随温度升高而减小，随压强增大而增大。"],
        ["化学 · 原理", "酸碱中和一定放热，但放热的不一定是中和反应。"],
        ["化学 · 原理", "电解水得到氢气和氧气的体积比是 2:1，注意是体积比不是质量比。"],
        ["化学 · 原理", "燃烧需要三个条件：可燃物、氧气、达到着火点，缺一不可。"],
        ["化学 · 生活", "灭火就是破坏其中一个条件：清除可燃物、隔绝氧气或降温。"],
        ["化学 · 生活", "二氧化碳能灭火，是因为它不助燃且密度比空气大。"],
        ["化学 · 原理", "酸溶液一定显酸性，但显酸性的不一定是酸溶液，比如硫酸氢钠。"],
        ["化学 · 原理", "碱溶液一定显碱性，但显碱性的不一定是碱溶液，比如碳酸钠。"],
        ["化学 · 原理", "金属越活泼，越容易和氧气反应，所以钾钠要保存在煤油里。"],
        ["化学 · 原理", "铁生锈是铁和氧气、水共同作用的结果，缺一个都不行。"],
        ["化学 · 原理", "化学式中的数字表示原子个数，方程式中的系数表示分子个数。"],
        ["化学 · 原理", "相对原子质量没有单位，它是一个比值。"],
        ["化学 · 原理", "摩尔质量在数值上等于相对分子质量，但单位是 g/mol。"],
        ["化学 · 原理", "标准状况下，1 mol 任何气体的体积都约是 22.4 L。"],
        ["化学 · 原理", "阿伏加德罗常数是 6.02×10²³，表示 1 mol 物质的粒子数。"],
        ["化学 · 原理", "浓度越大、温度越高、接触面积越大，反应速率越快。"],

        /* ==================== 化学 · 实验操作与安全 ==================== */
        ["化学 · 实验", "闻气体要用手扇着闻，不能把鼻子凑到瓶口直接吸。"],
        ["化学 · 实验", "加热试管时要先预热，且试管口不能对着人。"],
        ["化学 · 实验", "不能用嘴吹灭酒精灯，要用灯帽盖两次。"],
        ["化学 · 实验", "实验剩余的药品不能放回原瓶，要倒入指定容器。"],
        ["化学 · 实验", "稀释浓硫酸时：酸入水、慢慢倒、边倒边搅。"],
        ["化学 · 实验", "金属钠要保存在煤油里，因为它遇水会剧烈反应。"],
        ["化学 · 实验", "白磷要保存在水里，它在空气中会自燃。"],
        ["化学 · 安全", "汞洒落要立即用硫粉覆盖，防止蒸气中毒。"],
        ["化学 · 安全", "钾、钠、镁等活泼金属着火不能用水或二氧化碳灭火器。"],
        ["化学 · 安全", "电器着火先断电，再用干粉或二氧化碳灭火器，不能用水。"],
        ["化学 · 安全", "闻到刺激性气味且眼睛刺痛，立刻离开并开窗通风。"],
        ["化学 · 实验", "实验服要扣好，长发要扎起来，不穿凉鞋进实验室。"],
        ["化学 · 实验", "玻璃仪器加热前要检查有没有裂纹。"],
        ["化学 · 实验", "量筒不能加热，也不能用作反应容器。"],
        ["化学 · 实验", "托盘天平称量时左物右码，药品不能直接放在托盘上。"],
        ["化学 · 实验", "胶头滴管不能伸入试管内，要悬空滴加。"],
        ["化学 · 实验", "有毒气体的实验必须在通风橱里做。"],
        ["化学 · 实验", "废液不能直接倒下水道，要分类回收。"],
        ["化学 · 实验", "任何实验前都要先读一遍步骤，想清楚每一步为什么这么做。"],
        ["化学 · 安全", "遇到意外先保护自己：着火用湿布盖，化学品溅到皮肤立刻用大量清水冲。"],
        ["化学 · 口诀", "茶庄定点收利息——制氧气七步：查（气密性）装（药品）定（固定）点（点燃）收（收集）离（撤导管）熄（熄灯）。"],
        ["化学 · 口诀", "先离后熄——排水法收集完，导管必须先撤出水槽再熄灯，不然水会倒吸炸试管。"],
        ["化学 · 口诀", "一贴二低三靠——过滤要领：滤纸贴漏斗、液面低于滤纸边、漏斗颈靠烧杯壁。"],
        ["化学 · 口诀", "上不碰下不靠——温度计测液体温度时，玻璃泡不能碰容器底和壁。"],
        ["化学 · 实验", "蒸发结晶时要用玻璃棒不停搅拌，防止局部过热液滴飞溅。"],
        ["化学 · 实验", "蒸馏时温度计的水银球要放在支管口处，不是插进液体里。"],
        ["化学 · 实验", "分液漏斗使用前要检查是否漏液。"],
        ["化学 · 实验", "点燃可燃性气体前必须验纯，否则可能爆炸。"],
        ["化学 · 实验", "氢气还原氧化铜要先通氢气再加热，结束时要先撤灯再停氢气。"],
        ["化学 · 实验", "一氧化碳还原氧化铁要做尾气处理，因为它有毒。"],
        ["化学 · 实验", "配制溶液时，溶质要先在烧杯里溶解再转移到容量瓶。"],
        ["化学 · 实验", "定容时最后要用胶头滴管加水，不能直接倒。"],
        ["化学 · 实验", "pH 试纸不能直接伸进待测液，要用玻璃棒蘸取滴在试纸上。"],
        ["化学 · 实验", "pH 试纸不能用水润湿，否则相当于稀释了待测液。"],
        ["化学 · 实验", "取用固体药品要用镊子或药匙，不能用手拿。"],
        ["化学 · 实验", "块状固体放入试管时要先横放再慢慢竖起，让它滑下去。"],
        ["化学 · 实验", "试管夹要从试管底部往上套，夹在离管口三分之一处。"],
        ["化学 · 实验", "给液体加热时液体体积不能超过试管容积的三分之一。"],
        ["化学 · 实验", "洗过的试管要倒放在试管架上晾干。"],
        ["化学 · 实验", "试管刷洗试管时要上下移动并转动，不能只捅底部。"],

        /* ==================== 物理 · 力与运动 ==================== */
        ["物理 · 力学", "惯性不是力，是物体保持原来运动状态的性质。说「受到惯性」是错的。"],
        ["物理 · 力学", "质量是物体固有的，重量会随重力加速度变化——在月球上你会更轻，但质量不变。"],
        ["物理 · 力学", "摩擦力不总是阻力，走路、握笔、刹车都靠它。"],
        ["物理 · 力学", "压强 = 压力 ÷ 受力面积。图钉尖细是为了增大压强，书包带宽是为了减小。"],
        ["物理 · 力学", "液体压强只跟深度和密度有关，跟容器形状无关。"],
        ["物理 · 力学", "大气压约等于 10 米高水柱产生的压强，所以抽水机理论上最多抽 10 米。"],
        ["物理 · 力学", "浮力等于排开液体的重力，这就是阿基米德原理。"],
        ["物理 · 力学", "物体浮沉看密度：比液体密度小就浮，大就沉，相等就悬浮。"],
        ["物理 · 力学", "轮船是钢铁做的却能浮，因为做成了空心，平均密度小于水。"],
        ["物理 · 力学", "杠杆平衡条件：动力 × 动力臂 = 阻力 × 阻力臂。"],
        ["物理 · 力学", "定滑轮不省力只改变方向，动滑轮省一半力但要多拉一倍距离。"],
        ["物理 · 力学", "任何机械都不省功，这就是「机械效率永远小于 100%」的原因。"],
        ["物理 · 力学", "牛顿第一定律：不受外力时，物体保持静止或匀速直线运动。"],
        ["物理 · 力学", "物体运动不需要力来维持，力是改变运动状态的原因。"],
        ["物理 · 力学", "作用力与反作用力大小相等、方向相反，但作用在两个不同物体上，不能抵消。"],
        ["物理 · 力学", "同一直线上两个力：同向相加，反向相减。"],
        ["物理 · 力学", "做功有两个要素：有力，且在力的方向上通过了距离。"],
        ["物理 · 力学", "提着东西水平走路不做功，因为力的方向和位移方向垂直。"],
        ["物理 · 力学", "功率表示做功的快慢，不是做功的多少。"],
        ["物理 · 力学", "动能看质量和速度，速度影响更大——因为是平方关系。"],
        ["物理 · 力学", "重力势能看质量和高度，举得越高、越重，势能越大。"],
        ["物理 · 力学", "机械能等于动能加势能，只有重力做功时机械能守恒。"],
        ["物理 · 力学", "摩擦力大小跟压力和接触面粗糙程度有关，跟接触面积无关。"],
        ["物理 · 力学", "滑动摩擦比滚动摩擦大，所以轮子比滑块省力。"],
        ["物理 · 力学", "物体做匀速直线运动时，受到的合力为零。"],
        ["物理 · 力学", "平衡力和作用力反作用力的区别：前者作用在同一物体上。"],
        ["物理 · 力学", "重心不一定在物体上，比如圆环的重心在圆心。"],
        ["物理 · 力学", "弹簧测力计的原理是「弹簧伸长量与拉力成正比」。"],
        ["物理 · 力学", "使用弹簧测力计前要检查指针是否指零。"],
        ["物理 · 力学", "密度是物质的一种特性，跟质量和体积都无关。"],

        /* ==================== 物理 · 光声热电 ==================== */
        ["物理 · 光学", "光在真空中的速度约 3×10⁸ m/s，是宇宙中速度的上限。"],
        ["物理 · 光学", "光年是距离单位，不是时间单位——指光走一年的距离。"],
        ["物理 · 光学", "天空是蓝的，因为短波蓝光被空气分子散射得更厉害（瑞利散射）。"],
        ["物理 · 光学", "日落时太阳发红，因为光穿过更厚的大气，蓝光被散射掉了。"],
        ["物理 · 光学", "彩虹是阳光在水滴里折射、反射再折射形成的，红色在外紫色在内。"],
        ["物理 · 光学", "镜子里的像是虚像，左右没有反，反的是前后。"],
        ["物理 · 光学", "凸透镜能聚光，凹透镜能发散，近视戴凹透镜，远视戴凸透镜。"],
        ["物理 · 光学", "影子边缘模糊，是因为光源不是理想的点光源。"],
        ["物理 · 光学", "反射定律：三线共面、两线分居、两角相等。"],
        ["物理 · 光学", "光从空气斜射入水中时，折射角小于入射角。"],
        ["物理 · 光学", "凸透镜成像：一倍焦距分虚实，二倍焦距分大小。"],
        ["物理 · 光学", "凸透镜成实像时，物近像远像变大。"],
        ["物理 · 光学", "平面镜成像，像和物到镜面的距离相等。"],
        ["物理 · 光学", "小孔成像成的是倒立的实像。"],
        ["物理 · 光学", "光在同种均匀介质中沿直线传播。"],
        ["物理 · 声学", "声音在真空中不能传播，太空里是绝对安静的。"],
        ["物理 · 声学", "15℃ 空气中声速约 340 m/s，温度越高声速越快。"],
        ["物理 · 声学", "先看到闪电后听到雷声，因为光速远大于声速。"],
        ["物理 · 声学", "回声是声音被反射回来，原声和回声间隔超过 0.1 秒人耳才能分开。"],
        ["物理 · 声学", "频率高于 20000 Hz 是超声波，低于 20 Hz 是次声波，人耳都听不到。"],
        ["物理 · 声学", "音调由频率决定，响度由振幅决定，音色由发声体本身决定。"],
        ["物理 · 声学", "声音在固体中传播最快，液体次之，气体最慢。"],
        ["物理 · 声学", "发声的物体一定在振动，振动停止发声也停止。"],
        ["物理 · 声学", "超声波能用来清洗和碎石，因为它能量集中。"],
        ["物理 · 声学", "噪声控制有三个途径：声源处、传播过程中、人耳处。"],
        ["物理 · 热学", "水在 4℃ 时密度最大，所以冬天湖面结冰是从上往下冻，鱼能在水底过冬。"],
        ["物理 · 热学", "冰的密度比水小，所以冰浮在水面上——这是水的「反常膨胀」。"],
        ["物理 · 热学", "热胀冷缩对水不成立：0~4℃ 之间水是「热缩冷胀」的。"],
        ["物理 · 热学", "绝对零度是 -273.15℃，是理论上的最低温度，永远达不到。"],
        ["物理 · 热学", "温度是分子平均动能的标志，不是「热的多少」。"],
        ["物理 · 热学", "热量总是自发地从高温物体传到低温物体，不会反过来。"],
        ["物理 · 热学", "高压锅煮得快，是因为压强高沸点高，水温能超过 100℃。"],
        ["物理 · 热学", "高原上水不到 100℃ 就开了，因为气压低沸点低，饭容易夹生。"],
        ["物理 · 热学", "出汗能降温，靠的是汗水蒸发时吸收热量。"],
        ["物理 · 热学", "冬天呼出「白气」是水蒸气遇冷液化成小水滴，不是气态的「白气」。"],
        ["物理 · 热学", "保温瓶能保温，靠的是真空层阻断传导和对流、镀银层反射辐射。"],
        ["物理 · 热学", "改变内能有两种方式：做功和热传递。"],
        ["物理 · 热学", "晶体熔化时吸热但温度不变，这个温度叫熔点。"],
        ["物理 · 热学", "蒸发在任何温度下都能发生，沸腾只在沸点时发生。"],
        ["物理 · 电学", "摩擦起电是电子转移，不是「产生了电荷」——电荷总量始终守恒。"],
        ["物理 · 电学", "串联电路电流处处相等，并联电路各支路电压相等。"],
        ["物理 · 电学", "欧姆定律 I = U ÷ R，电压是原因，电流是结果，电阻是阻碍。"],
        ["物理 · 电学", "电流通过导体发热叫电流的热效应，电炉、电热毯都靠它。"],
        ["物理 · 电学", "家庭电路并联接，所以关一个灯不影响其他灯。"],
        ["物理 · 电学", "同种电荷相斥，异种电荷相吸。"],
        ["物理 · 电学", "串联分压，并联分流。"],
        ["物理 · 电学", "导体和绝缘体没有绝对界限，条件变了可以互相转化。"],
        ["物理 · 电学", "电阻大小跟材料、长度、横截面积有关，跟电压电流无关。"],
        ["物理 · 电学", "短路时电流很大，容易引起火灾，所以保险丝要选对规格。"],
        ["物理 · 电学", "发电机用右手定则，电动机用左手定则。"],
        ["物理 · 电学", "电磁铁磁性强弱跟电流大小和线圈匝数有关。"],
        ["物理 · 电学", "指南针指南北是因为地球本身是个大磁体。"],
        ["物理 · 电学", "磁感线是假想的曲线，实际并不存在。"],
        ["物理 · 电学", "同名磁极相斥，异名磁极相吸。"],
        ["物理 · 电学", "电能表测的是电功，单位是千瓦时也就是「度」。"],
        ["物理 · 电学", "额定功率是正常工作时的功率，实际功率会随电压变化。"],
        ["物理 · 电学", "安全用电原则：不接触低压带电体，不靠近高压带电体。"],
        ["物理 · 综合", "能量既不会凭空产生也不会凭空消失，只会转化或转移——能量守恒定律。"],
        ["物理 · 综合", "物理学中很多规律都是「守恒」：能量守恒、质量守恒、电荷守恒、动量守恒。"]
    ];

    // ============================================================
    // 一、左下角悬浮卡（全站）
    //     默认收起成一个小灯泡圆球，鼠标移上去展开；手机上点一下展开。
    //     关掉之后本次浏览不再出现（sessionStorage 记住）。
    // ============================================================
    var CSS_FLOAT =
        '.nb-tip-fab{' +
        'position:fixed;left:18px;bottom:18px;z-index:9000;' +
        'width:46px;height:46px;border-radius:50%;' +
        'display:flex;align-items:center;justify-content:center;' +
        'font-size:1.25rem;cursor:pointer;' +
        'border:1px solid rgba(128,128,128,.28);' +
        'background:var(--card,#fff);color:inherit;' +
        'box-shadow:0 6px 20px rgba(0,0,0,.14);' +
        'transition:transform .22s cubic-bezier(.34,1.4,.64,1),box-shadow .22s;' +
        'animation:nbTipPulse 3.2s ease-in-out 4;' +
        '}' +
        '.nb-tip-fab:hover{transform:scale(1.1) rotate(-8deg);box-shadow:0 8px 26px rgba(0,0,0,.2);}' +
        '@keyframes nbTipPulse{' +
        '0%,100%{box-shadow:0 6px 20px rgba(0,0,0,.14);}' +
        '50%{box-shadow:0 6px 20px rgba(0,0,0,.14),0 0 0 8px rgba(96,165,250,.14);}' +
        '}' +
        '.nb-tip-panel{' +
        'position:fixed;left:76px;bottom:18px;z-index:9000;' +
        'width:min(430px,calc(100vw - 104px));' +
        'box-sizing:border-box;padding:14px 16px;border-radius:14px;' +
        'border:1px solid var(--line,rgba(128,128,128,.22));' +
        'background:var(--card,#fff);color:var(--ink,inherit);' +
        'font-size:.88rem;line-height:1.7;' +
        'box-shadow:0 10px 34px rgba(0,0,0,.18);' +
        'opacity:0;visibility:hidden;transform:translateX(-10px);' +
        'transition:opacity .2s,transform .2s,visibility .2s;' +
        '}' +
        '.nb-tip-fab:hover + .nb-tip-panel,' +
        '.nb-tip-panel:hover,' +
        '.nb-tip-wrap.nb-open .nb-tip-panel{opacity:1;visibility:visible;transform:translateX(0);}' +
        '.nb-tip-close{' +
        'position:absolute;top:6px;right:8px;cursor:pointer;' +
        'font-size:.95rem;line-height:1;opacity:.4;background:none;border:none;color:inherit;' +
        '}' +
        '.nb-tip-close:hover{opacity:1;}' +
        '.nb-tip-tag{' +
        'display:inline-block;margin-right:8px;padding:1px 8px;border-radius:999px;' +
        'font-size:.7rem;border:1px solid var(--line,rgba(128,128,128,.28));' +
        'background:rgba(96,165,250,.12);color:#3b82f6;vertical-align:1px;white-space:nowrap;' +
        '}' +
        '.nb-tip-next{' +
        'margin-top:9px;cursor:pointer;font-size:.76rem;opacity:.55;' +
        'padding:3px 10px;border-radius:8px;background:none;color:inherit;' +
        'border:1px solid var(--line,rgba(128,128,128,.28));' +
        '}' +
        '.nb-tip-next:hover{opacity:1;}' +
        '@media (max-width:640px){' +
        '.nb-tip-fab{left:12px;bottom:12px;width:42px;height:42px;font-size:1.1rem;}' +
        '.nb-tip-panel{left:12px;right:12px;bottom:64px;width:auto;}' +
        '}';

    // ============================================================
    // 二、首页固定板块 + 评论区上方（页内嵌）
    // ============================================================
    var CSS_INLINE =
        '.nb-tip-box{' +
        'max-width:900px;margin:26px auto;padding:16px 20px;box-sizing:border-box;' +
        'border:1px solid var(--line,rgba(128,128,128,.22));border-radius:16px;' +
        'background:var(--card,rgba(128,128,128,.05));color:var(--ink,inherit);' +
        'font-size:.92rem;line-height:1.8;position:relative;overflow:hidden;' +
        '}' +
        '.nb-tip-box::before{' +
        'content:"";position:absolute;left:0;top:0;bottom:0;width:3px;' +
        'background:linear-gradient(180deg,#60a5fa,#a78bfa);' +
        '}' +
        '.nb-tip-box .nb-tip-head{' +
        'font-size:.78rem;font-weight:700;letter-spacing:.04em;' +
        'color:#3b82f6;margin-bottom:7px;' +
        '}' +
        '.nb-tip-box .nb-tip-text{font-size:.95rem;}' +
        '.nb-tip-box .nb-tip-next{float:right;margin-top:0;}' +
        '.nb-tip-slim{' +
        'max-width:900px;margin:0 auto 14px;padding:11px 16px;box-sizing:border-box;' +
        'border:1px dashed var(--line,rgba(128,128,128,.28));border-radius:12px;' +
        'background:rgba(96,165,250,.05);color:var(--ink,inherit);' +
        'font-size:.85rem;line-height:1.7;opacity:.92;' +
        '}' +
        '@media (max-width:640px){' +
        '.nb-tip-box{margin:20px 12px;padding:14px 16px;}' +
        '.nb-tip-slim{margin:0 12px 12px;padding:10px 13px;font-size:.82rem;}' +
        '}';

    function injectCSS() {
        if (document.getElementById('nbTipStyle')) return;
        var st = document.createElement('style');
        st.id = 'nbTipStyle';
        st.textContent = CSS_FLOAT + CSS_INLINE;
        document.head.appendChild(st);
    }

    // ---------- 小工具 ----------
    var idx = Math.floor(Math.random() * TIPS.length);
    function nextIndex() {
        var n = idx;
        while (TIPS.length > 1 && n === idx) n = Math.floor(Math.random() * TIPS.length);
        return n;
    }
    function fill(box) {
        var t = TIPS[idx];
        var tag = box.querySelector('.nb-tip-tag');
        var txt = box.querySelector('.nb-tip-text');
        if (tag) tag.textContent = t[0];
        if (txt) txt.textContent = t[1];
    }
    function makeNextBtn(box) {
        var b = document.createElement('button');
        b.className = 'nb-tip-next';
        b.type = 'button';
        b.textContent = '换一条';
        b.onclick = function (e) {
            e.stopPropagation(); e.preventDefault();
            idx = nextIndex();
            // 同一页上可能有多处，全部一起换，保持一致
            var all = document.querySelectorAll('.nb-tip-box,.nb-tip-slim,.nb-tip-panel');
            for (var i = 0; i < all.length; i++) fill(all[i]);
        };
        return b;
    }
    function makeTag() { var s = document.createElement('span'); s.className = 'nb-tip-tag'; return s; }
    function makeText() { var s = document.createElement('span'); s.className = 'nb-tip-text'; return s; }

    // ---------- ① 左下悬浮 ----------
    // sessionStorage 在隐私模式 / 禁用 Cookie 时可能直接抛错，
    // 一旦抛出来整个悬浮卡就挂了，所以全部包起来
    function tipOff() {
        try { return sessionStorage.getItem('nb_tip_off') === '1'; } catch (e) { return false; }
    }
    function setTipOff() {
        try { sessionStorage.setItem('nb_tip_off', '1'); } catch (e) {}
    }

    function mountFloat() {
        if (document.getElementById('nbTipFloat')) return;
        if (tipOff()) return;

        var wrap = document.createElement('div');
        wrap.className = 'nb-tip-wrap';
        wrap.id = 'nbTipFloat';

        var fab = document.createElement('div');
        fab.className = 'nb-tip-fab';
        fab.title = '看一条化学 / 物理小知识';
        fab.textContent = '💡';
        // 手机上没有 hover，点一下切换
        fab.onclick = function () { wrap.classList.toggle('nb-open'); };

        var panel = document.createElement('div');
        panel.className = 'nb-tip-panel';

        var close = document.createElement('button');
        close.className = 'nb-tip-close';
        close.type = 'button';
        close.title = '关闭（本次浏览不再显示）';
        close.textContent = '✕';
        close.onclick = function (e) {
            e.stopPropagation();
            setTipOff();
            wrap.parentNode && wrap.parentNode.removeChild(wrap);
        };

        var body = document.createElement('div');
        body.appendChild(makeTag());
        body.appendChild(makeText());
        body.appendChild(document.createElement('br'));
        body.appendChild(makeNextBtn(panel));

        panel.appendChild(close);
        panel.appendChild(body);
        wrap.appendChild(fab);
        wrap.appendChild(panel);
        document.body.appendChild(wrap);
        fill(panel);
    }

    // ---------- ② 首页板块 ----------
    function isHome() {
        var p = location.pathname;
        if (/\/Beta\/index-Beta\.html$/.test(p)) return true;
        if (/\/(index\.html)?$/.test(p)) return true;
        return false;
    }
    function mountHomeBox() {
        var exist = document.querySelector('.nb-tip-box');
        if (!exist) {
            exist = document.createElement('div');
            exist.className = 'nb-tip-box';
            var head0 = document.createElement('div');
            head0.className = 'nb-tip-head';
            head0.textContent = 'Tips：';
            var body0 = document.createElement('div');
            body0.appendChild(makeTag());
            body0.appendChild(makeText());
            body0.appendChild(makeNextBtn(exist));
            exist.appendChild(head0);
            exist.appendChild(body0);
            fill(exist);
        }
        var box = exist;
        box.className = 'nb-tip-box';
        // 首页首屏那些模块（hero / 统计 / 核心功能 / 友商）是 ui-nav.js
        // 后来注入的，抓不准时机。这里改成"挂在主容器最前面"——
        // 主容器第一个子元素一定是导航栏（ui-nav.js 也是插在那），
        // 所以插在导航之后、hero 之前，是页面上最稳也最显眼的位置。
        var cont = document.querySelector('.container')
                || document.querySelector('main')
                || document.body;

        // 首选：公告之后（站长要求）
        // 注意：原始 HTML 里那个 #announcementBar 会被 ui-nav.js 直接【移除】，
        // 然后它自己重新注入一个 .beta-announce。所以优先认后者。
        var ann = document.querySelector('.beta-announce')
               || document.querySelector('.announcement-bar')
               || document.getElementById('betaAnnounce')
               || document.getElementById('announcementBar');
        if (ann && ann.parentNode && document.body.contains(ann)) {
            if (box.previousElementSibling !== ann) {
                ann.parentNode.insertBefore(box, ann.nextSibling);
            }
            fill(box);
            window.__nbAnchor = '公告之后';
            return true;
        }

        // 其次：主容器里、导航栏之后（导航必须在最上面）
        if (cont) {
            // 找导航：ui-nav.js 生成的那条，或者任何带 nav 字样的元素
            var ref = null;
            var navEl = cont.querySelector('.top-nav')
                     || cont.querySelector('[class*="nav"]')
                     || cont.querySelector('nav');
            // 只认主容器【直接子元素】里的导航，避免抓到面包屑之类的
            if (navEl && navEl.parentNode === cont) ref = navEl;

            if (ref) {
                if (!(box.parentNode === cont && box.previousElementSibling === ref)) {
                    cont.insertBefore(box, ref.nextSibling);
                }
                fill(box);
                window.__nbAnchor = '导航之后';
                return true;
            }

            // 找不到导航就退回"最前面"
            if (!(box.parentNode === cont && cont.firstElementChild === box)) {
                cont.insertBefore(box, cont.firstElementChild);
            }
            fill(box);
            window.__nbAnchor = '容器最前';
            return true;
        }

        // 兜底：原始 HTML 里那张"友商链接"卡片之前
        var anchor = null;
        var cards = document.querySelectorAll('.home-card');
        for (var i2 = 0; i2 < cards.length; i2++) {
            var t = cards[i2].textContent || '';
            if (t.indexOf('友商') >= 0 || t.indexOf('虚拟公司的网站') >= 0) {
                anchor = { n: cards[i2], after: false };
                break;
            }
        }
        if (!anchor) {
            var sc = document.querySelector('.stats-container');
            if (sc && sc.parentNode) anchor = { n: sc, after: false };
        }
        if (!anchor) return false;

        // 已经在正确位置就不动，否则挪过去（首页内容是异步渲染的，
        // 第一次进来可能还找不到"友商"那张卡片，等 DOM 稳定后要能纠正）
        if (anchor.after) {
            if (box.previousElementSibling !== anchor.n) {
                anchor.n.parentNode.insertBefore(box, anchor.n.nextSibling);
            }
        } else {
            if (box.nextElementSibling !== anchor.n) {
                anchor.n.parentNode.insertBefore(box, anchor.n);
            }
        }
        fill(box);
        return true;
    }

    // ---------- ③ 评论区上方 ----------
    function mountAboveComments() {
        var cs = document.getElementById('comments') || document.querySelector('.comment-section');
        if (!cs || !cs.parentNode) return false;
        // 已经插过（多页共用脚本时防重）
        if (cs.previousElementSibling && cs.previousElementSibling.classList &&
            cs.previousElementSibling.classList.contains('nb-tip-slim')) return true;

        var box = document.createElement('div');
        box.className = 'nb-tip-slim';
        box.appendChild(makeTag());
        box.appendChild(makeText());
        box.appendChild(makeNextBtn(box));
        cs.parentNode.insertBefore(box, cs);
        fill(box);
        return true;
    }

    // ---------- 挂载 ----------
    function mount() {
        injectCSS();
        mountFloat();
        mountAboveComments();
        if (isHome()) mountHomeBox();
    }

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', mount);
    } else {
        mount();
    }
    // 页面上有些内容是异步渲染的（评论列表、首页那些 ui-nav.js 注入的模块），
    // 所以要补插几次。这里统一用一个定时器轮询，不做 DOM 监听 ——
    //   ⚠️ 之前用 MutationObserver 盯整棵文档树，页面渲染时 DOM 变动极频繁，
    //      每次变动都触发查询，会拖慢加载。改成低频轮询后开销可忽略。
    function tryHome() {
        try {
            if (!isHome()) return false;
            return mountHomeBox();
        } catch (e) { return false; }
    }

    var _n = 0;
    var _timer = setInterval(function () {
        _n++;
        try { mountAboveComments(); } catch (e) {}
        if (isHome()) tryHome();
        // 跑够 10 次（约 4 秒）就停，不管成没成，不给页面留负担
        if (_n >= 10) { clearInterval(_timer); _timer = null; }
    }, 400);

    // 首屏立刻试一次，别等到 400ms 后
    try { mountAboveComments(); } catch (e) {}
    if (isHome()) tryHome();

    window.NBTips = {
        all: TIPS,
        count: TIPS.length,
        random: function () { return TIPS[Math.floor(Math.random() * TIPS.length)]; },
        reset: function () { try { sessionStorage.removeItem('nb_tip_off'); } catch (e) {} location.reload(); }
    };
})();
