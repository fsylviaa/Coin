// 答案（2026-10，作者要的"答案之书"玩法）。
//
// 每一抛落定前，硬币下面淡淡浮出一句话：上面中文，下面小字英文。
//
// ★ 像《答案之书》那样：读起来像是在回答你，但模棱两可，让人自己去想（作者定的）★。
//   改过三版，作者划下的线：
//   • 不替人拿主意：第一版"再等一等""去做吧"太有指向性。硬币已经在帮人选了，这句话不再推一把。
//     所以不用祈使句，不说"该/别/去"。
//   • 不要光秃秃的含糊话："是也不是""差不多""谁知道呢"没有内容，作者不要。
//   • 不要纯写景的古诗：试过混进公有领域的古典名句，作者说很多意境不合适，已全部撤掉。
//   • 不要有暗示性的：不预设具体的人、消息、时间、地点、梦（"你在等的人也在犹豫"
//     "月圆之前会有消息"这种），只往提问的人自己心里指。
//   好的样子：像在回应提问的人，又把问题轻轻推回给他——
//   "你心里偏向的那一面，就是线索""那要看你更怕失去什么""硬币落下前，你就有了偏心"。
// ★ 和哪面朝上无关，单独随机（作者定的）★——需求里规定两面不带含义，这句话是另抽的，
//   日面、月面都可能配上任何一句。
//
// ★ 全部是我们自己写的 ★。《答案之书》原书（Carol Bolt）的句子有版权，一句都不能搬。
//   以后要增删，直接改下面的表；中英要成对，每句都要短，一眼读完。
//
// 一共 200 句（原书约几百条，作者要凑到 200）。只学原书的味道，每句都从零写，
// 不照着原书逐条改写意思——那样等于换个说法搬原书。
//
// 抽法：一副洗好的牌，一张一张往下翻，翻完再洗——短时间内不会重复同一句。

import Foundation

struct Answer: Equatable, Identifiable {
    let zh: String
    let en: String
    var id: String { zh }
}

enum AnswerBook {

    static let all: [Answer] = [
        .init(zh: "答案比你以为的近", en: "Closer than you think"),
        .init(zh: "你其实不是在问这个", en: "That's not really what you're asking"),
        .init(zh: "你心里偏向的那一面，就是线索", en: "The side you hope for is a clue"),
        .init(zh: "那要看你更怕失去什么", en: "It depends on what you fear losing more"),
        .init(zh: "它比看上去重，也比看上去轻", en: "Heavier than it looks, and lighter"),
        .init(zh: "结果会说话，但不会说全", en: "The outcome speaks, but not all of it"),
        .init(zh: "它会带来另一个问题", en: "It will bring another question"),
        .init(zh: "你已经替它找好了理由", en: "You've already found your reasons"),
        .init(zh: "时间会站到某一边", en: "Time will take a side"),
        .init(zh: "两条路会在某处相遇", en: "The two roads meet somewhere"),
        .init(zh: "你问的时候，答案就开始变了", en: "The answer shifted when you asked"),
        .init(zh: "不止一个答案是对的", en: "More than one answer is right"),
        .init(zh: "你会在意想不到的地方知道", en: "You'll find out somewhere unexpected"),
        .init(zh: "它会以另一种方式发生", en: "It will happen another way"),
        .init(zh: "一部分答案，你已经有了", en: "Part of the answer is already yours"),
        .init(zh: "它会让你更了解自己", en: "It will teach you about yourself"),
        .init(zh: "答案会在你不找的时候出现", en: "It comes when you stop looking"),
        .init(zh: "后来的你会有不同的看法", en: "Later, you will see it differently"),
        .init(zh: "不是硬币能回答的", en: "Not something a coin can answer"),
        .init(zh: "硬币只知道一半", en: "The coin knows only half"),
        .init(zh: "另一面也在等你", en: "The other side is waiting too"),
        .init(zh: "每一面都是真的", en: "Every face is true"),
        .init(zh: "没有错的那一面", en: "Neither side is wrong"),
        .init(zh: "你在等一个允许", en: "You're waiting for permission"),
        .init(zh: "你要的也许不是答案，是勇气", en: "Maybe it's courage, not an answer"),
        .init(zh: "问题会自己长大", en: "The question will grow on its own"),
        .init(zh: "它不会停在这里", en: "It won't end here"),
        .init(zh: "有些东西已经在路上", en: "Something is already on its way"),
        .init(zh: "你比问题更早知道", en: "You knew before the question did"),
        .init(zh: "没你想的那么要紧", en: "Less depends on it than you think"),
        .init(zh: "比你想的更要紧", en: "More depends on it than you think"),
        .init(zh: "换一个人问，答案会不同", en: "Asked by someone else, it would differ"),
        .init(zh: "答案藏在你没说出口的部分", en: "It hides in what you left unsaid"),
        .init(zh: "你已经回答过一次了", en: "You've answered this once before"),
        .init(zh: "它取决于一件你还不知道的事", en: "It hinges on something you don't know yet"),
        .init(zh: "有一个细节会改变一切", en: "One detail will change everything"),
        .init(zh: "一切照旧，又有一点不同", en: "As before, but slightly different"),
        .init(zh: "风向会变", en: "The wind will shift"),
        .init(zh: "现在还看不清，但会的", en: "Not clear yet, but it will be"),
        .init(zh: "有一天你会笑着讲起它", en: "Someday you'll tell it with a smile"),
        .init(zh: "你会感谢某个意外", en: "You'll be grateful for an accident"),
        .init(zh: "它就在你反复想的那一句里", en: "It's in the line you keep repeating"),
        .init(zh: "你想听的，也许就是真的", en: "What you want to hear may be true"),
        .init(zh: "是一个开始，也可能是告别", en: "A beginning, or perhaps a goodbye"),
        .init(zh: "会有回音", en: "There will be an echo"),
        .init(zh: "回音会比声音大", en: "The echo will be louder than the call"),
        .init(zh: "有些事不需要答案也会过去", en: "Some things pass without an answer"),
        .init(zh: "问题本身已经说明了一切", en: "The question says it all"),
        .init(zh: "你两个都想要", en: "You want both"),
        .init(zh: "你两个都不想要", en: "You want neither"),
        .init(zh: "第三个选项还没出现", en: "The third option hasn't appeared yet"),
        .init(zh: "你漏看了一个选项", en: "There's an option you've missed"),
        .init(zh: "它不是非此即彼", en: "It isn't either-or"),
        .init(zh: "答案在你的犹豫里", en: "The answer is in your hesitation"),
        .init(zh: "你在等的信号已经来过", en: "The sign you're waiting for has come"),
        .init(zh: "结果会让你意外", en: "The result will surprise you"),
        .init(zh: "不会是你以为的样子", en: "It won't look the way you expect"),
        .init(zh: "会比想象中安静", en: "Quieter than you imagine"),
        .init(zh: "它需要的时间比你给的多", en: "It needs more time than you're giving"),
        .init(zh: "有一扇门你还没敲", en: "There's a door you haven't knocked on"),
        .init(zh: "绕一圈会回到原处", en: "Around the circle, back to the start"),
        .init(zh: "答案会穿着旧衣服回来", en: "The answer returns in old clothes"),
        .init(zh: "一个你没问的问题会先有答案", en: "An unasked question gets answered first"),
        .init(zh: "你已经不是问这个问题时的你", en: "You're no longer the one who asked"),
        .init(zh: "你知道的比你承认的多", en: "You know more than you admit"),
        .init(zh: "你不知道的那部分更重要", en: "What you don't know matters more"),
        .init(zh: "它会留下痕迹", en: "It will leave a mark"),
        .init(zh: "有些答案要用很久才懂", en: "Some answers take years to understand"),
        .init(zh: "今天的答案，明天的问题", en: "Today's answer, tomorrow's question"),
        .init(zh: "硬币落下前，你就有了偏心", en: "You chose a side before it landed"),
        .init(zh: "你在心里已经抛过了", en: "You've already flipped it inside"),
        .init(zh: "结果只是让你看清自己", en: "The result only shows you yourself"),
        .init(zh: "不论哪面，你都会想起另一面", en: "Either way, you'll think of the other"),
        .init(zh: "另一面不会消失", en: "The other side doesn't disappear"),
        .init(zh: "得到和失去会一起来", en: "Gain and loss will come together"),
        .init(zh: "它有它自己的节奏", en: "It has its own rhythm"),
        .init(zh: "你会被一件小事说服", en: "Something small will convince you"),
        .init(zh: "它会以你没想到的方式成真", en: "It comes true in a way you didn't expect"),
        .init(zh: "有些答案只在路上", en: "Some answers live only on the road"),
        .init(zh: "你问得越轻，听得越清", en: "The softer you ask, the clearer you hear"),
        .init(zh: "你越想知道，它越安静", en: "The more you want it, the quieter it gets"),
        .init(zh: "一半在你，一半在天", en: "Half is yours, half is the sky's"),
        .init(zh: "这不是你最后一次问", en: "This won't be the last time you ask"),
        .init(zh: "你心里那枚硬币早就落地了", en: "The coin inside you landed long ago"),
        .init(zh: "你在找的不是答案，是确认", en: "It's reassurance you're after"),
        .init(zh: "你会选能让你睡着的那个", en: "You'll pick the one that lets you sleep"),
        .init(zh: "未来的你已经知道了", en: "Your future self already knows"),
        .init(zh: "答案在你下一次深呼吸里", en: "The answer is in your next deep breath"),
        .init(zh: "不是现在，也不是从不", en: "Not now, and not never"),
        .init(zh: "会比你想的早", en: "Sooner than you think"),
        .init(zh: "会比你想的晚", en: "Later than you think"),
        .init(zh: "你问的，也在问你", en: "What you ask is asking you"),
        .init(zh: "你已经在答案里", en: "You are already inside the answer"),
        .init(zh: "你早就听过这个答案", en: "You've heard this answer before"),
        .init(zh: "答案在问题的背面", en: "The answer is on the back of the question"),
        .init(zh: "落地之前，一切都可能", en: "Before it lands, anything is possible"),
        .init(zh: "你看到的只是一面", en: "You see only one face"),
        .init(zh: "硬币也在猜", en: "The coin is guessing too"),
        .init(zh: "时间会给它名字", en: "Time will give it a name"),
        .init(zh: "也许已经发生了", en: "Perhaps it has already happened"),
        .init(zh: "有些事只有你知道", en: "Some things only you can know"),
        .init(zh: "明天会知道", en: "Tomorrow will know"),
        .init(zh: "看不见不等于不在", en: "Unseen is not absent"),
        .init(zh: "沉默也是一种回答", en: "Silence is an answer too"),
        .init(zh: "无解也是一种解", en: "No answer is an answer"),
        .init(zh: "答案和你的问题一样长", en: "The answer is as long as your question"),
        .init(zh: "问题越重，答案越轻", en: "Heavier question, lighter answer"),
        .init(zh: "你已经比刚才确定一点了", en: "You're a little surer than a moment ago"),
        .init(zh: "问出口的时候，你松了一口气", en: "Asking it already let out a breath"),
        .init(zh: "答案不止一层", en: "The answer has more than one layer"),
        .init(zh: "第一层你已经看见了", en: "You've already seen the first layer"),
        .init(zh: "剩下的会慢慢显出来", en: "The rest will show itself slowly"),
        .init(zh: "它有一个你没注意到的角度", en: "It has an angle you haven't noticed"),
        .init(zh: "它比你记得的更小", en: "It's smaller than you remember"),
        .init(zh: "它比你想象的更大", en: "It's bigger than you imagine"),
        .init(zh: "你想得太远了，也可能不够远", en: "Too far ahead, or not far enough"),
        .init(zh: "答案不在硬币上", en: "The answer isn't on the coin"),
        .init(zh: "硬币只是让你听见自己", en: "The coin only lets you hear yourself"),
        .init(zh: "它不会一直是个问题", en: "It won't always be a question"),
        .init(zh: "有些问题会自己变成答案", en: "Some questions turn into answers"),
        .init(zh: "你此刻的感觉就是一部分答案", en: "How you feel now is part of it"),
        .init(zh: "它会跟着你一起变", en: "It will change as you do"),
        .init(zh: "它会比你先变", en: "It will change before you do"),
        .init(zh: "你想要的，正在换样子", en: "What you want is changing shape"),
        .init(zh: "你担心的已经小了一点", en: "Your worry has already shrunk a little"),
        .init(zh: "确定感会来，但不会久留", en: "Certainty will come, but not stay"),
        .init(zh: "不确定也是一种答案", en: "Uncertainty is an answer too"),
        .init(zh: "答案在你停下来的地方", en: "The answer is where you pause"),
        .init(zh: "它不必今天就完整", en: "It needn't be whole today"),
        .init(zh: "每个答案都会留下一个问号", en: "Every answer leaves a question mark"),
        .init(zh: "回头看时，它会不一样", en: "Looking back, it will look different"),
        .init(zh: "你已经走了一半", en: "You're already halfway"),
        .init(zh: "答案会比问题活得久", en: "The answer will outlive the question"),
        .init(zh: "它没有你想的那么新", en: "It's not as new as you think"),
        .init(zh: "答案已经被你说出口过", en: "You've already said the answer aloud"),
        .init(zh: "它会在一个普通的下午揭晓", en: "It reveals itself on an ordinary afternoon"),
        .init(zh: "这件事比你更有耐心", en: "This is more patient than you"),
        .init(zh: "你害怕的，和你想的不一样", en: "What you fear isn't what you think"),
        .init(zh: "答案会先让你不太舒服", en: "The answer will unsettle you first"),
        .init(zh: "过一阵你会忘了这个问题", en: "In a while, you'll forget this question"),
        .init(zh: "它在等一个更好的问题", en: "It's waiting for a better question"),
        .init(zh: "真正的问题藏在后面", en: "The real question is behind this one"),
        .init(zh: "你已经站在门口了", en: "You're already at the door"),
        .init(zh: "有些事失去了才看得清", en: "Some things are clear only once lost"),
        .init(zh: "三年前的你会给出另一个答案", en: "Three years ago, you'd answer otherwise"),
        .init(zh: "十年后它只是一个细节", en: "In ten years, it's just a detail"),
        .init(zh: "这是一个会被记住的选择", en: "This choice will be remembered"),
        .init(zh: "它不会像你担心的那样结束", en: "It won't end the way you fear"),
        .init(zh: "也不会像你希望的那样开始", en: "Nor begin the way you hope"),
        .init(zh: "它和你上次问的是同一件事", en: "It's what you asked last time"),
        .init(zh: "你一直在绕着它走", en: "You've been circling around it"),
        .init(zh: "绕开它的路也是路", en: "The way around is also a way"),
        .init(zh: "它会变得更简单", en: "It will become simpler"),
        .init(zh: "它会变得更有意思", en: "It will become more interesting"),
        .init(zh: "你会多一个理由", en: "You'll gain one more reason"),
        .init(zh: "你会少一个担心", en: "You'll lose one worry"),
        .init(zh: "别人的答案不是你的", en: "Someone else's answer isn't yours"),
        .init(zh: "答案写在你常走的路上", en: "It's written on the road you often walk"),
        .init(zh: "它比你想的更早开始了", en: "It began earlier than you think"),
        .init(zh: "它会让你多看一眼", en: "It will make you look twice"),
        .init(zh: "这是你的问题，也是别人的", en: "Your question, and someone else's"),
        .init(zh: "你会在最后一刻知道", en: "You'll know at the last moment"),
        .init(zh: "你会发现自己早就选了", en: "You'll find you chose long ago"),
        .init(zh: "你会想起很久以前的一句话", en: "You'll recall something said long ago"),
        .init(zh: "这次和上次不一样", en: "This time is not like last time"),
        .init(zh: "你比上次更清楚", en: "You see more clearly than last time"),
        .init(zh: "你比你以为的更在乎", en: "You care more than you think"),
        .init(zh: "你没有你以为的那么在乎", en: "You care less than you think"),
        .init(zh: "答案很近，只是被挡住了", en: "Close, but hidden behind something"),
        .init(zh: "中间那样东西会移开", en: "What stands between will move"),
        .init(zh: "天平已经倾斜了", en: "The scale has already tipped"),
        .init(zh: "天平还在晃", en: "The scale is still swinging"),
        .init(zh: "你听得见自己的答案", en: "You can hear your own answer"),
        .init(zh: "你只是想有人替你说出来", en: "You just want someone to say it"),
        .init(zh: "等你不急了，它就来了", en: "It comes once you stop rushing"),
        .init(zh: "它会把你带回原来的地方", en: "It will lead you back where you began"),
        .init(zh: "新的地方也有旧的影子", en: "New places hold old shadows"),
        .init(zh: "你会遇见一个相似的问题", en: "You'll meet a similar question"),
        .init(zh: "每一次问，你都在变", en: "Each time you ask, you change"),
        .init(zh: "它会是你故事里的一小段", en: "It'll be a small part of your story"),
        .init(zh: "故事还远没有结束", en: "The story is far from over"),
        .init(zh: "这一页很快会翻过去", en: "This page will turn soon"),
        .init(zh: "下一页更有意思", en: "The next page is more interesting"),
        .init(zh: "你心里的声音比你想的大", en: "Your inner voice is louder than you think"),
        .init(zh: "有个声音你一直没理", en: "There's a voice you've been ignoring"),
        .init(zh: "你会在镜子里看到它", en: "You'll see it in the mirror"),
        .init(zh: "说到底，它和你自己有关", en: "In the end, it's about you"),
        .init(zh: "一切都更清楚的那天会来", en: "A clearer day is coming"),
        .init(zh: "那一天不会太远", en: "That day isn't far"),
        .init(zh: "你会觉得一切都说得通", en: "It will all make sense"),
        .init(zh: "也许永远说不通，也没关系", en: "It may never make sense, and that's fine"),
        .init(zh: "问的时候，你已经长大了一点", en: "In asking, you grew a little"),
        .init(zh: "它会让你变得更柔软", en: "It will soften you"),
        .init(zh: "它会让你变得更坚硬", en: "It will harden you"),
        .init(zh: "答案会改变你提问的方式", en: "The answer will change how you ask"),
        .init(zh: "你的问题里有一个字不对", en: "One word in your question is off"),
        .init(zh: "把问题倒过来，答案也倒过来", en: "Turn the question over, the answer too"),
        .init(zh: "越简单的那个越难", en: "The simpler one is the harder one"),
        .init(zh: "越难的那个越像你", en: "The harder one is more like you"),
        .init(zh: "它在你的计划之外", en: "It's outside your plan"),
    ]

    /// 一副洗好的牌：翻完一轮才会再洗，短时间内不会重复
    struct Deck {
        private var order: [Int] = []
        private var last: Int?

        mutating func draw<G: RandomNumberGenerator>(using rng: inout G) -> Answer {
            if order.isEmpty {
                order = Array(AnswerBook.all.indices).shuffled(using: &rng)
                // 新一轮的第一张别正好是上一轮的最后一张
                if order.count > 1, order.last == last { order.swapAt(0, order.count - 1) }
            }
            let i = order.removeLast()
            last = i
            return AnswerBook.all[i]
        }

        mutating func draw() -> Answer {
            var g = SystemRandomNumberGenerator()
            return draw(using: &g)
        }
    }
}
