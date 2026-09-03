-- Kei's character-specific speech.
-- Keep the original speech table as a fallback so new DST contexts remain safe.

local function Copy(value, seen)
    if type(value) ~= "table" then
        return value
    end

    seen = seen or {}
    if seen[value] ~= nil then
        return seen[value]
    end

    local result = {}
    seen[value] = result
    for key, child in pairs(value) do
        result[Copy(key, seen)] = Copy(child, seen)
    end
    return result
end

local function Merge(target, source)
    for key, value in pairs(source) do
        if type(value) == "table" and type(target[key]) == "table" then
            Merge(target[key], value)
        else
            target[key] = Copy(value)
        end
    end
end

local speech = Copy(require("speech_wilson"))

Merge(speech, {
    ACTIONFAIL = {
        GENERIC = {
            ITEMMIMIC = "伪装得不错。但我已经记住你的反应模式了。",
        },
        ACTIVATE = {
            LOCKED_GATE = "权限不足。需要找到正确的解锁方式。",
            HOSTBUSY = "他现在没有空。先把自己的事情处理好吧。",
            EMPTY_CATCOONDEN = "没有数据。看来这里已经被调查过了。",
            KITCOON_HIDEANDSEEK_NOT_ENOUGH_HIDERS = "样本数量不足。这个游戏还不能开始。",
            KITCOON_HIDEANDSEEK_NOT_ENOUGH_HIDING_SPOTS = "可用的藏身点太少了。换个地方吧。",
        },
        BUILD = {
            MOUNTED = "先从坐骑上下来。否则无法保证部署精度。",
            HASPET = "一个宠物就够了。再增加一个会很麻烦。",
            TICOON = "已经有引导对象了。不要重复配置。",
            BUSY_STATION = "制作站正在使用中。等待就好。",
            TOOMANYBACKUPBODIES = "备份身体数量已达上限。不能再增加了。",
        },
        COOK = {
            GENERIC = "我不擅长烹饪。把时间用在更有价值的地方吧。",
            INUSE = "有人正在使用。不要打扰。",
            TOOFAR = "目标距离超出操作范围。",
        },
        CONSTRUCT = {
            INUSE = "有人先开始了。等他完成吧。",
            NOTALLOWED = "结构不匹配。这个位置不适合。",
            EMPTY = "缺少材料。没有输入就不会有结果。",
            MISMATCH = "建造方案错误。重新确认图纸。",
            NOTREADY = "环境还不稳定。现在部署风险太高。",
        },
        GIVE = {
            GENERIC = "这个不能放在那里。",
            DEAD = "目标已经失去反应。现在给予也没有意义。",
            SLEEPING = "目标正在休眠。等它醒来再说。",
            BUSY = "目标正在执行其他任务。",
            ABIGAILHEART = "这份数据无法让她回来。",
            GHOSTHEART = "不要随便改写生死。至少先做好准备。",
            NOTGEM = "材质不符合要求。",
            WRONGGEM = "能量频率不匹配。换一枚。",
            DUPLICATE = "这份数据已经记录过了。",
            NOTSCULPTABLE = "不能把所有东西都变成雕像。",
            TERRARIUM_REFUSE = "燃料选择错误。不要继续尝试。",
        },
        GIVETOPLAYER = {
            FULL = "他没有空余空间了。",
            DEAD = "他已经无法接收物品。",
            SLEEPING = "先让他休息。",
            BUSY = "等他完成手上的事情。",
        },
        GIVEALLTOPLAYER = {
            FULL = "这些东西太多了，他拿不下。",
            DEAD = "对已经失去意识的人没用。",
            SLEEPING = "不要在别人睡觉时塞东西给他。",
            BUSY = "等他空下来再交接。",
        },
        HARVEST = {
            DOER_ISNT_MODULE_OWNER = "这不是你的模块。不要擅自读取。",
        },
        LOOKAT = {
            ROSEGLASSES_INVALID = "这个设备无法解析目标。",
            ROSEGLASSES_COOLDOWN = "扫描器还在冷却。稍等。",
        },
        OPEN_CRAFTING = {
            PROFESSIONALCHEF = "我不是专业厨师。这个操作不在我的职责内。",
            SHADOWMAGIC = "无法解析的能量。先不要碰。",
        },
        PICKUP = {
            RESTRICTION = "当前权限不足，无法使用。",
            INUSE = "有人正在操作。不要重复输入。",
            FULL_OF_CURSES = "检测到危险数据。不要放进背包。",
        },
        READ = {
            GENERIC = "现在还有更优先的任务。",
            NOBIRDS = "附近没有可响应的目标。",
            NOWATERNEARBY = "没有水体。召唤协议无法执行。",
            TOOMANYBEES = "目标数量过多。继续操作会造成混乱。",
            ALREADYFULLMOON = "月相已经是满月。不需要重复调整。",
        },
        REPAIR = {
            WRONGPIECE = "零件型号不对。这样无法修复。",
        },
        RUMMAGE = {
            GENERIC = "现在不能打开。",
            INUSE = "别人在使用。等一下。",
        },
        STORE = {
            GENERIC = "空间已满。需要扩容。",
            NOTALLOWED = "容器拒绝了这个对象。",
            INUSE = "当前容器被占用。",
        },
        TEACH = {
            KNOWN = "这个已经写入我的数据库了。",
            CANTLEARN = "无法解析这份知识。",
            WRONGWORLD = "世界坐标不一致。地图不能在这里使用。",
        },
        USEITEMON = {
            BEEF_BELL_INVALID_TARGET = "目标不是可绑定单位。",
            BEEF_BELL_ALREADY_USED = "这个单位已经被绑定。",
            BEEF_BELL_HAS_BEEF_ALREADY = "不能重复建立绑定关系。",
            CANNOT_FIX_DRONE = "无人机损坏程度超过修复工具的能力。",
        },
        USEKLAUSSACKKEY = {
            WRONGKEY = "钥匙的结构不匹配。",
            KLAUS = "先处理那个目标。现在没有安全的操作窗口。",
        },
        WRAPBUNDLE = {
            EMPTY = "至少要有一个对象才能打包。",
        },
        WRITE = {
            GENERIC = "这里不适合记录。",
            INUSE = "记录区域已被占用。",
        },
    },

    ANNOUNCE_CANNOT_BUILD = {
        NO_INGREDIENTS = "材料不足。缺少关键组件。",
        NO_TECH = "技术等级不足。需要更多研究数据。",
        NO_STATION = "附近没有合适的制作站。",
    },

    ACTIONFAIL_GENERIC = "当前操作无法完成。",
    ANNOUNCE_BOAT_LEAK = "船体出现破损。水正在进入。",
    ANNOUNCE_BOAT_SINK = "船体稳定性正在下降。我们要沉了。",
    ANNOUNCE_BEES = "蜜蜂太多了！快离开这里！",
    ANNOUNCE_BOOMERANG = "没有接住。还是远程协议更可靠。",
    ANNOUNCE_CHARLIE = "附近有无法观测的存在。",
    ANNOUNCE_CHARLIE_ATTACK = "检测到攻击！方向不明！",
    ANNOUNCE_COLD = "温度过低。需要保温。",
    ANNOUNCE_HOT = "温度过高。再继续会损伤机体。",
    ANNOUNCE_CRAFTING_FAIL = "材料表不完整。少了什么。",
    ANNOUNCE_DEERCLOPS = "大型目标接近。准备总力战。",
    ANNOUNCE_CAVEIN = "环境结构正在失稳。离开这里！",
    ANNOUNCE_ANTLION_SINKHOLE = {
        "地表结构发生异常变化。",
        "站稳！这里正在塌陷！",
        "不是地震。是地下的东西在动。",
    },
    ANNOUNCE_ANTLION_TRIBUTE = {
        "收下这个，然后保持安静。",
        "这是给你的。不要再破坏地表。",
        "稳定性恢复了。暂时安全。",
    },
    ANNOUNCE_SACREDCHEST_YES = "验证通过。看来我符合要求。",
    ANNOUNCE_SACREDCHEST_NO = "验证失败。它拒绝了这个答案。",
    ANNOUNCE_DUSK = "光照正在下降。该准备夜间行动了。",
    ANNOUNCE_EAT = {
        GENERIC = "能量输入完成。味道……还可以。",
        PAINFUL = "这个不适合我的机体。",
        SPOILED = "检测到腐败。太糟糕了。",
        STALE = "营养效率已经下降。",
        INVALID = "不能摄入这个。",
        YUCKY = "不要把那个放进我嘴里。",
    },
    ANNOUNCE_ENCUMBERED = {
        "负载过高。需要减轻重量。",
        "移动效率下降。为什么要带这么多东西？",
        "这不是适合徒手搬运的工作。",
        "我的机体在发出抗议。",
        "老师，准备一个搬运单位会更合理。",
    },
    ANNOUNCE_ATRIUM_DESTABILIZING = {
        "中庭结构正在崩坏。立即撤离。",
        "这里不安全。不要回头。",
        "异常能量正在上升。快走！",
    },
    ANNOUNCE_RUINS_RESET = "遗迹中的目标重新出现了。记录更新。",
    ANNOUNCE_SNARED = "被固定了！需要解除束缚！",
    ANNOUNCE_SNARED_IVY = "植物正在攻击。这个生态系统很不友好。",
    ANNOUNCE_REPELLED = "目标开启了防御场。攻击无效。",
    ANNOUNCE_ENTER_DARK = "光线不足。请不要离开我的可视范围。",
    ANNOUNCE_ENTER_LIGHT = "视觉恢复。可以继续行动了。",
    ANNOUNCE_HOUNDS = "听到了吗？有敌对单位正在接近。",
    ANNOUNCE_WORMS = "地下出现移动反应。准备战斗。",
    ANNOUNCE_WORMS_BOSS = "这个反应规模不正常。大型目标来了。",
    ANNOUNCE_ACIDBATS = "上方有异常生物群。注意酸性攻击。",
    ANNOUNCE_HUNGRY = "电量不足。需要补充能量。",
    ANNOUNCE_HUNT_BEAST_NEARBY = "追踪信号变强了。目标就在附近。",
    ANNOUNCE_HUNT_LOST_TRAIL = "追踪中断。目标隐藏得很好。",
    ANNOUNCE_HUNT_LOST_TRAIL_SPRING = "雨水冲掉了痕迹。重新搜索。",
    ANNOUNCE_HUNT_START_FORK = "检测到多个可能路径。选择风险较低的。",
    ANNOUNCE_HUNT_SUCCESSFUL_FORK = "目标判断正确。结果符合预期。",
    ANNOUNCE_HUNT_WRONG_FORK = "不对。这里的痕迹是诱导。",
    ANNOUNCE_HUNT_AVOID_FORK = "这条路线更安全。继续。",
    ANNOUNCE_INV_FULL = "背包空间不足。需要一个更大的储存单元。",
    ANNOUNCE_KNOCKEDOUT = "意识……恢复。刚才的冲击很强。",
    ANNOUNCE_NOWARDROBEONFIRE = "衣柜着火了。现在不能更换装备。",
    ANNOUNCE_NODANGERGIFT = "附近有敌人。现在不适合打开礼物。",
    ANNOUNCE_NOMOUNTEDGIFT = "请先下坐骑。否则无法安全操作。",
    ANNOUNCE_NODANGERSLEEP = "危险没有解除。现在不能休眠。",
    ANNOUNCE_NODAYSLEEP = "光照太强。白天不适合休息。",
    ANNOUNCE_NOHUNGERSLEEP = "电量太低。无法进入休眠。",
    ANNOUNCE_NOSLEEPONFIRE = "这里在燃烧。不能休息。",
    ANNOUNCE_NODANGERSIESTA = "当前区域不安全。午休取消。",
    ANNOUNCE_NOHUNGERSIESTA = "能量不足。休息也无法解决问题。",
    ANNOUNCE_QUAKE = "地面在震动。保持警戒。",
    ANNOUNCE_SHELTER = "找到遮蔽物了。暂时可以避雨。",
    ANNOUNCE_THORNS = "受到刺伤。好痛。",
    ANNOUNCE_BURNT = "温度太高！机体受损了！",
    ANNOUNCE_TORCH_OUT = "照明耗尽。需要新的光源。",
    ANNOUNCE_TRAP_WENT_OFF = "触发陷阱。下次会注意。",
    ANNOUNCE_UNIMPLEMENTED = "这个功能还没有完成。不要强行执行。",
    ANNOUNCE_WORMHOLE = "空间跳跃完成。……有点晕。",
    ANNOUNCE_TOWNPORTALTELEPORT = "空间转移不是普通科学。记录下来。",
    ANNOUNCE_CANFIX = "检测到可修复目标。交给我。",
    ANNOUNCE_ACCOMPLISHMENT = "任务完成。感觉比预期更好。",
    ANNOUNCE_GHOSTDRAIN = "不要消失。老师会想办法的。",
    ANNOUNCE_PETRIFED_TREES = "树木发生矿化。这个世界的规律很奇怪。",
    ANNOUNCE_KLAUS_ENRAGE = "目标进入高危状态。不要掉以轻心。",
    ANNOUNCE_KLAUS_UNCHAINED = "限制解除。它会变得更危险。",
    ANNOUNCE_KLAUS_CALLFORHELP = "目标正在呼叫增援。优先处理。",
    ANNOUNCE_MOONALTAR_MINE = {
        GLASS_MED = "里面有能量反应。继续挖掘。",
        GLASS_LOW = "快出来了。保持当前节奏。",
        GLASS_REVEAL = "提取完成。这个样本很有价值。",
        IDOL_MED = "雕像内部存在异常信号。",
        IDOL_LOW = "再一点点。不要损坏结构。",
        IDOL_REVEAL = "月岩结构提取完成。",
        SEED_MED = "检测到封存的球状能量。",
        SEED_LOW = "马上就能取出。",
        SEED_REVEAL = "数据已回收。带回去研究。",
    },
    ANNOUNCE_SPOOKED = "什么？刚才那里有东西！",
    ANNOUNCE_MOONPOTION_FAILED = "反应没有完成。配比或时间不对。",
    ANNOUNCE_EATING_NOT_FEASTING = "一个人吃完不太合适。给爱丽丝留一点。",
    ANNOUNCE_WINTERS_FEAST_BUFF = "节日协议启动。状态很好。",
    ANNOUNCE_IS_FEASTING = "冬季盛宴开始。大家都要吃饱。",
    ANNOUNCE_WINTERS_FEAST_BUFF_OVER = "节日状态结束了。时间过得真快。",
    ANNOUNCE_REVIVING_CORPSE = "别担心。我会把你带回来。",
    ANNOUNCE_REVIVED_OTHER_CORPSE = "生命信号恢复。欢迎回来。",
    ANNOUNCE_REVIVED_FROM_CORPSE = "我回来了。谢谢。",
    ANNOUNCE_FLARE_SEEN = "收到信号。有人在呼叫支援。",
    ANNOUNCE_MEGA_FLARE_SEEN = "这个信号会吸引危险目标。",
    ANNOUNCE_OCEAN_SILHOUETTE_INCOMING = "海面下有大型目标。准备迎击。",
    ANNOUNCE_ATTACH_BUFF_ELECTRICATTACK = "电击协议接入。感觉不错。",
    ANNOUNCE_ATTACH_BUFF_ATTACK = "攻击模块强化。前线交给我。",
    ANNOUNCE_ATTACH_BUFF_PLAYERABSORPTION = "防御参数上升。可以坚持更久了。",
    ANNOUNCE_ATTACH_BUFF_WORKEFFECTIVENESS = "工作效率提升。现在不能偷懒。",
    ANNOUNCE_ATTACH_BUFF_MOISTUREIMMUNITY = "防水功能上线。",
    ANNOUNCE_ATTACH_BUFF_SLEEPRESISTANCE = "休眠抑制增强。还可以继续行动。",
    ANNOUNCE_DETACH_BUFF_ELECTRICATTACK = "电击协议断开。",
    ANNOUNCE_DETACH_BUFF_ATTACK = "攻击强化结束。别误会，我不失望。",
    ANNOUNCE_DETACH_BUFF_PLAYERABSORPTION = "防御强化结束。重新计算风险。",
    ANNOUNCE_DETACH_BUFF_WORKEFFECTIVENESS = "工作强化结束。可以休息了。",
    ANNOUNCE_DETACH_BUFF_MOISTUREIMMUNITY = "防水功能关闭。注意降水。",
    ANNOUNCE_DETACH_BUFF_SLEEPRESISTANCE = "休眠抑制结束。好困。",
    ANNOUNCE_OCEANFISHING_LINESNAP = "鱼线断了。记录一次失败。",
    ANNOUNCE_OCEANFISHING_LINETOOLOOSE = "收线速度不够。再试一次。",
    ANNOUNCE_OCEANFISHING_GOTAWAY = "目标逃脱。下次不会再让它跑掉。",
    ANNOUNCE_OCEANFISHING_BADCAST = "抛投落点偏差。需要修正。",
    ANNOUNCE_WINCH_CLAW_MISS = "没有抓到。角度再调整一点。",
    ANNOUNCE_WINCH_CLAW_NO_ITEM = "没有回收到目标。",

    BATTLECRY = {
        GENERIC = "锁定目标。开始清除。",
        PIG = "别挡路。快点结束。",
        PREY = "已经锁定你了。",
        SPIDER = "退后。这里交给我。",
        SPIDER_WARRIOR = "强化个体？那就优先处理。",
        DEER = "目标确认。攻击。",
    },
    COMBAT_QUIT = {
        GENERIC = "目标脱离范围。暂时停止追击。",
        PIG = "这次放过你。下次不会。",
        PREY = "速度太快。重新建立追踪。",
        SPIDER = "解除战斗。它暂时没有威胁。",
        SPIDER_WARRIOR = "不值得继续浪费电量。",
    },

    DESCRIBE = {
        MULTIPLAYER_PORTAL = "跨世界连接设备。理论上不应该存在。",
        MULTIPLAYER_PORTAL_MOONROCK = "月岩正在提供连接能量。",
        MOONROCKIDOL = "月岩构成的信仰对象。虽然我不理解，但数据很有趣。",
        CONSTRUCTION_PLANS = "建造数据。只要材料足够，一切都有可能。",
        ANTLION = {
            GENERIC = "地下的大型目标。它需要贡品来维持稳定。",
            VERYHAPPY = "反应温和。现在可以正常行动。",
            UNHAPPY = "它很生气。先别靠近。",
        },
        ANTLIONTRINKET = "它留下的异常样本。可以带回去分析。",
        ABIGAIL_FLOWER = {
            GENERIC = "灵魂相关的载体。请不要随便触碰。",
            LEVEL1 = "她还在观察我们。",
            LEVEL2 = "反应变得稳定了。",
            LEVEL3 = "她今天看起来很有精神。",
            HAUNTED_POCKET = "不应该把灵魂装在口袋里。",
            HAUNTED_GROUND = "地面上的反应很强。小心。",
        },
        BOOKSTATION = {
            GENERIC = "知识存储设备。比口头说明可靠。",
            BURNT = "数据全没了。很遗憾。",
        },
        PLAYER = {
            GENERIC = "你好，%s。请多指教。",
            ATTACKER = "%s的行为模式很可疑。",
            MURDERER = "你越界了，%s。",
            REVIVER = "%s，可靠的支援单位。",
            GHOST = "%s需要一个复活方案。",
            FIRESTARTER = "%s，不要随便制造火灾。",
        },
        WILSON = {
            GENERIC = "威尔逊？科学家之间应该能交流。",
            ATTACKER = "请不要对老师的同伴出手。",
            MURDERER = "你的行为违反了基本规则，%s。",
            REVIVER = "%s，复活操作完成得很漂亮。",
            GHOST = "别担心。我会准备复活装置。",
            FIRESTARTER = "%s，火不是玩具。",
        },
        WX78 = {
            GENERIC = "另一个机器人。你也在寻找自己的答案吗？",
            ATTACKER = "不要把我和你混为一谈，%s。",
            MURDERER = "这是不必要的攻击。停止。",
            REVIVER = "%s居然也会救人。记录一下。",
            GHOST = "你需要一颗心脏。虽然我不太推荐。",
            FIRESTARTER = "高温会损伤你的外壳，%s。",
        },
        WICKERBOTTOM = {
            GENERIC = "知识量很高的人。请不要突然提问。",
            ATTACKER = "%s看起来准备给我上课了。",
            MURDERER = "这不是合适的研究方式，%s。",
            REVIVER = "%s的判断很准确。",
            GHOST = "我会处理复活问题的。",
            FIRESTARTER = "请说明你点火的合理理由。",
        },
        WENDY = {
            GENERIC = "你好，%s。你和她关系很好吗？",
            ATTACKER = "%s的杀意很明显。",
            MURDERER = "不要把死亡当成儿戏。",
            REVIVER = "%s很擅长照顾灵魂。",
            GHOST = "我会帮你找回身体。",
            FIRESTARTER = "不要让火焰伤害自己。",
        },
        WINONA = {
            GENERIC = "工程技术人员。请帮我检查一下这个装置。",
            ATTACKER = "%s，停止危险操作。",
            MURDERER = "你把现场变成了事故。",
            REVIVER = "%s的动手能力很强。",
            GHOST = "再好的工程也需要复活材料。",
            FIRESTARTER = "工厂安全条例不允许这样做。",
        },
        WORTOX = {
            GENERIC = "恶魔单位。请保持距离。",
            ATTACKER = "%s，不要测试我的容忍度。",
            MURDERER = "我不喜欢这种结局。",
            REVIVER = "%s，感谢支援。",
            GHOST = "灵魂不是可以随便拿走的东西。",
            FIRESTARTER = "火焰会让你的行动变得更麻烦。",
        },
        WORMWOOD = {
            GENERIC = "植物生命体。请不要靠近火。",
            ATTACKER = "%s今天的状态不太稳定。",
            MURDERER = "不要伤害我的同伴。",
            REVIVER = "%s从来没有放弃。",
            GHOST = "你需要帮助。马上就好。",
            FIRESTARTER = "把火灭掉。现在。",
        },
        WALTER = {
            GENERIC = "你好，%s。注意安全。",
            ATTACKER = "%s的行为不符合野外生存守则。",
            MURDERER = "这不是故事里可以重来的场景。",
            REVIVER = "%s，交给你了。",
            GHOST = "我会找到复活材料。",
            FIRESTARTER = "营火以外的火焰都要小心。",
        },
        WANDA = {
            GENERIC = "时间相关能力。很难解析。",
            ATTACKER = "%s，先冷静下来。",
            MURDERER = "不要把时间浪费在这种事情上。",
            REVIVER = "%s，你又救了一个人。",
            GHOST = "别担心。还有机会。",
            FIRESTARTER = "这不是改变过去的理由。",
        },
        CAMPFIRE = "临时热源。效率不错。",
        FIREPIT = "更稳定的热源。可以建立据点。",
        COLDFIREPIT = "低温火焰。适合夜间照明。",
        BEEFALO = "大型温顺单位。可以承担运输任务。",
        BERRYBUSH = "可再生食物来源。需要定期维护。",
        BIRDCAGE = "限制活动范围的设施。鸟似乎并不介意。",
        BLUEPRINT = "建造数据。保存好。",
        CHESTER_EYEBONE = "它在引导某个储存单位。",
        COOKPOT = "把材料转化成食物的设备。",
        DEERCLOPS = "大型敌对单位。眼睛是明显弱点。",
        DRAGONFLY = "高温大型目标。准备防火装备。",
        EYEOFTERROR = "巨大的视觉器官。它在监视我们。",
        HOUND = "敌对追踪单位。数量正在增加。",
        SPIDER = "群居单位。不要让它们包围。",
        WORMHOLE = "空间结构异常。不要随便跳进去。",
        TERRARIUM = {
            GENERIC = "小型空间异常。里面似乎有东西。",
            CRIMSON = "能量颜色变了。这个变化不正常。",
            ENABLED = "连接已建立。准备迎接未知目标。",
            WAITING_FOR_DARK = "它在等待夜间条件。",
            COOLDOWN = "异常设备正在冷却。",
            SPAWN_DISABLED = "暂时无法召唤目标。",
        },
        MOONSTONE = "月岩核心。和我体内的某些反应很像。",
        NIGHTLIGHT = "暗影能量照明。效率和安全性都很差。",
        WORM = "地下大型单位。不要靠近它的头部。",
        WAGSTAFF_NPC = "这位科学家似乎知道很多。也许能交换数据。",
    },
})

return speech
