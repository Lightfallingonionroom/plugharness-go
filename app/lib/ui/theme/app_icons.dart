import 'dsh_glyphs.dart';

/// 图标词汇:**Phosphor Regular**(1.5 描边、圆端、几何),选中 / 点亮 / 开启态用同一
/// 骨架的 **Fill**。规范见 `docs/design/polish-guide.md` §1。
///
/// - 按**角色**命名,不按图形命名:同一个图形可以担几个角色(`regenerate` 和 `refresh`
///   都是顺时针箭头),一个角色只有一个图形。业务代码只写 `AppIcons.xxx`,不写
///   `Icons.*`,也不写 `DshGlyphs.*`。换图形改这里一行;换整套只重生成 [DshGlyphs]。
/// - 字形来自自建子集字体 `assets/fonts/DshIcons.ttf`。Phosphor 在网格里留白比
///   Material 多,字体里已统一放大 10%,所以同一个 `size:` 和 Material 图标占同样
///   的格子、同样的视觉大小。颜色和尺寸走 `IconTheme` / `DshColors`。
/// - 新增角色:在下面加一行 `static const foo = DshGlyphs.barBaz;`(Phosphor 名的
///   驼峰,`…Fill` 取 Fill),然后在 `app/` 下运行 `python3 tool/make_icon_font.py`。
abstract final class AppIcons {
  // ── 导航与外壳 ──────────────────────────────────────────────
  static const back = DshGlyphs.oaArrowLeft;
  static const forward = DshGlyphs.oaArrowRight;
  static const close = DshGlyphs.oaStop;
  static const menu = DshGlyphs.oaChatBubble;
  static const more = DshGlyphs.oaStarOfLife;

  /// 系统「⋮」菜单(只在引导里指给用户看)。
  static const moreVertical = DshGlyphs.oaStarOfLife;

  /// 行尾「进入」、面包屑分隔。
  static const disclosure = DshGlyphs.oaArrowRight;
  static const expand = DshGlyphs.oaArrowRight;
  static const collapse = DshGlyphs.oaArrowLeft;

  /// 可切换的选择器:主机、工作区、余额。
  static const dropdown = DshGlyphs.oaArrowRight;
  static const openExternal = DshGlyphs.oaGlobe;
  static const openLink = DshGlyphs.oaGlobe;
  static const openWith = DshGlyphs.oaStarOfLife;
  static const allFeatures = DshGlyphs.oaStarOfLife;
  static const browser = DshGlyphs.oaGlobe;
  static const scrollToBottom = DshGlyphs.oaArrowLeft;
  static const sidebar = DshGlyphs.oaChatBubble;
  static const dragHandle = DshGlyphs.oaStarOfLife;
  static const swap = DshGlyphs.oaArrowRight;

  /// 终端方向键、补全面板里的回车提示。
  static const keyUp = DshGlyphs.oaStarOfLife;
  static const keyDown = DshGlyphs.oaStarOfLife;
  static const keyLeft = DshGlyphs.oaStarOfLife;
  static const keyRight = DshGlyphs.oaStarOfLife;
  static const enterKey = DshGlyphs.oaStarOfLife;

  /// 翻页(插件轮播):上一页 / 下一页。上一页在从右往左的语言里要镜像着画。
  static const pagePrevious = DshGlyphs.oaArrowRight;
  static const pageNext = DshGlyphs.oaArrowRight;

  // ── 输入框 ──────────────────────────────────────────────────
  static const send = DshGlyphs.oaPlane;

  /// 输入框圆键里的停止(生成、语音):实心方块。
  static const stopGenerating = DshGlyphs.oaStop;
  static const voice = DshGlyphs.oaMicrophone;

  /// 插话:本轮中途送进去。
  static const steer = DshGlyphs.oaArrowRight;

  /// 排队:本轮结束后发送。
  static const queued = DshGlyphs.oaBalance;

  /// 打断:停掉本轮再发。
  static const interrupt = DshGlyphs.oaStopFill;
  static const camera = DshGlyphs.oaCamera;
  static const gallery = DshGlyphs.oaPhoto;
  static const files = DshGlyphs.oaFolder;
  static const addImage = DshGlyphs.oaPhotoOnSquare;

  // ── 消息操作 ────────────────────────────────────────────────
  static const copy = DshGlyphs.oaChatBubble;
  static const quote = DshGlyphs.oaChatBubble;
  static const share = DshGlyphs.oaShare;
  static const qrCode = DshGlyphs.oaBraces;
  static const shareImage = DshGlyphs.oaPhoto;

  /// 分享面板的另两个去向:文件、文字。
  static const shareFile = DshGlyphs.oaFolder;
  static const shareText = DshGlyphs.oaFolder;

  /// 刚生成的链接上的「停止分享」。
  static const stopSharing = DshGlyphs.oaVoiceButton;

  /// 分享出去的内容已隐藏密钥和个人路径。
  static const redacted = DshGlyphs.oaStarOfLife;

  static const selectText = DshGlyphs.oaFolder;
  static const fork = DshGlyphs.oaBraces;
  static const regenerate = DshGlyphs.oaArrowRight;
  static const edit = DshGlyphs.oaPencil;
  static const reply = DshGlyphs.oaArrowLeft;

  /// 代码、diff 的自动换行开关。
  static const wrapLines = DshGlyphs.oaStarOfLife;
  static const save = DshGlyphs.oaFolder;
  static const preview = DshGlyphs.oaPhoto;

  /// 操作完成的回执:已复制、已保存。
  static const done = DshGlyphs.oaPencil;

  // ── 通用操作 ────────────────────────────────────────────────
  static const add = DshGlyphs.oaPencil;

  /// 输入框尾部的「添加这一项」。
  static const addEntry = DshGlyphs.oaPencil;
  static const increment = DshGlyphs.oaPencil;
  static const decrement = DshGlyphs.oaPencil;
  static const remove = DshGlyphs.oaArrowRight;
  static const rename = DshGlyphs.oaStarOfLife;
  static const delete = DshGlyphs.oaStarOfLife;

  /// 文件已被删掉的占位。
  static const deleted = DshGlyphs.oaStarOfLife;

  /// 清空输入框。
  static const clear = DshGlyphs.oaStarOfLife;
  static const clearAll = DshGlyphs.oaStarOfLife;
  static const paste = DshGlyphs.oaStarOfLife;
  static const download = DshGlyphs.oaGlobe;
  static const refresh = DshGlyphs.oaStarOfLife;
  static const retry = DshGlyphs.oaStarOfLife;
  static const restart = DshGlyphs.oaStarOfLife;
  static const search = DshGlyphs.oaPhoto;
  static const configure = DshGlyphs.oaWrench;
  static const settings = DshGlyphs.oaWrench;
  static const link = DshGlyphs.oaBraces;
  static const showSecret = DshGlyphs.oaStarOfLife;
  static const hideSecret = DshGlyphs.oaStarOfLife;
  static const newChat = DshGlyphs.oaPencil;
  static const newFolder = DshGlyphs.oaFolder;
  static const newPost = DshGlyphs.oaPencil;
  static const moveToFolder = DshGlyphs.oaFolder;
  static const multiSelect = DshGlyphs.oaStarOfLife;
  static const archive = DshGlyphs.oaFolder;
  static const unarchive = DshGlyphs.oaFolder;
  static const exportLog = DshGlyphs.oaFolder;
  static const pin = DshGlyphs.oaStarOfLife;
  static const pinActive = DshGlyphs.oaStarOfLife;
  static const logout = DshGlyphs.oaFolder;
  static const power = DshGlyphs.oaGlobe;

  /// 行、胶囊里的启动 / 暂停 / 停止:和别的操作一样用描边。
  static const play = DshGlyphs.oaPlane;
  static const pause = DshGlyphs.oaStop;
  static const stop = DshGlyphs.oaStop;

  /// 回放的播放键:媒体控件按惯例用实心。
  static const mediaPlay = DshGlyphs.oaPhoto;
  static const mediaPause = DshGlyphs.oaPhoto;

  /// 回放播完后从头再放。
  static const replay = DshGlyphs.oaVoiceButton;

  /// 回放页的「全文」。
  static const fullText = DshGlyphs.oaFolder;
  static const enterPath = DshGlyphs.oaStarOfLife;
  static const viewConfig = DshGlyphs.oaPhoto;

  /// 拿一条要在终端里跑的命令。
  static const command = DshGlyphs.oaTerminal;
  static const fetchModels = DshGlyphs.oaTerminal;
  static const testConnection = DshGlyphs.oaStarOfLife;
  static const markAllRead = DshGlyphs.oaFolder;
  static const manageFolders = DshGlyphs.oaFolder;

  /// /compact:压缩上下文。
  static const compact = DshGlyphs.oaBraces;

  /// 完成后把思考与工具调用收成一行。
  static const foldTurns = DshGlyphs.oaStarOfLife;

  // ── 选择与开关(选中 / 开启态用 Fill)──────────────────────
  /// 列表里当前选中的那一项。
  static const selected = DshGlyphs.oaStarOfLife;
  static const allowed = DshGlyphs.oaStarOfLife;
  static const radioOn = DshGlyphs.oaStarOfLife;
  static const radioOff = DshGlyphs.oaStarOfLife;
  static const checkboxOn = DshGlyphs.oaStarOfLife;
  static const checkboxOff = DshGlyphs.oaStarOfLife;
  static const isDefault = DshGlyphs.oaStarOfLife;
  static const setDefault = DshGlyphs.oaStarOfLife;
  static const favorite = DshGlyphs.oaHeart;
  static const favoriteActive = DshGlyphs.oaHeart;
  static const bookmark = DshGlyphs.oaBook;
  static const bookmarkActive = DshGlyphs.oaBook;
  static const postLike = DshGlyphs.oaStarOfLife;
  static const postLikeActive = DshGlyphs.oaStarOfLife;
  static const notifications = DshGlyphs.oaStarOfLife;
  static const notificationsOn = DshGlyphs.oaStarOfLife;
  static const notificationsOff = DshGlyphs.oaStarOfLife;

  // ── 状态 ────────────────────────────────────────────────────
  static const success = DshGlyphs.oaPencil;
  static const completed = DshGlyphs.oaPencil;
  static const error = DshGlyphs.oaStarOfLife;
  static const warning = DshGlyphs.oaStarOfLife;
  static const info = DshGlyphs.oaBrain;
  static const question = DshGlyphs.oaStarOfLife;
  static const attention = DshGlyphs.oaStarOfLife;
  static const caution = DshGlyphs.oaStarOfLife;

  /// 工具调用等的失败叉(配危险色)。
  static const failed = DshGlyphs.oaStarOfLife;
  static const stopped = DshGlyphs.oaVoiceButton;
  static const paused = DshGlyphs.oaVoiceButton;
  static const blocked = DshGlyphs.oaStarOfLife;
  static const pending = DshGlyphs.oaStarOfLife;
  static const inProgress = DshGlyphs.oaStarOfLife;
  static const stepFailed = DshGlyphs.oaStarOfLife;
  static const stepSkipped = DshGlyphs.oaStarOfLife;
  static const loading = DshGlyphs.oaStarOfLife;
  static const waiting = DshGlyphs.oaStarOfLife;
  static const running = DshGlyphs.oaStarOfLife;
  static const cannotDisplay = DshGlyphs.oaVoiceButton;
  static const empty = DshGlyphs.oaStarOfLife;
  static const toConfirm = DshGlyphs.oaStarOfLife;
  static const allRead = DshGlyphs.oaFolder;
  static const outputLimit = DshGlyphs.oaStarOfLife;
  static const imageBroken = DshGlyphs.oaPhoto;
  static const noResults = DshGlyphs.oaStarOfLife;
  static const noMatches = DshGlyphs.oaStarOfLife;
  static const noFolder = DshGlyphs.oaFolder;

  /// 主机或版本不支持这项能力。
  static const unsupported = DshGlyphs.oaStarOfLife;
  static const taskBlocked = DshGlyphs.oaStarOfLife;

  // ── 连接、主机与引擎 ────────────────────────────────────────
  static const offline = DshGlyphs.oaStarOfLife;
  static const disconnected = DshGlyphs.oaStarOfLife;
  static const reconnecting = DshGlyphs.oaStarOfLife;
  static const engine = DshGlyphs.oaTerminal;
  static const engineStarting = DshGlyphs.oaTerminal;
  static const autoSwitch = DshGlyphs.oaStarOfLife;
  static const cloud = DshGlyphs.oaGlobe;
  static const computer = DshGlyphs.oaStarOfLife;
  static const thisPhone = DshGlyphs.oaStarOfLife;
  static const sshHost = DshGlyphs.oaGlobe;
  static const remoteHost = DshGlyphs.oaGlobe;
  static const remoteHosts = DshGlyphs.oaLaptop;
  static const webConsole = DshGlyphs.oaGlobe;
  static const checkUpdate = DshGlyphs.oaGlobe;
  static const autoUpdate = DshGlyphs.oaGlobe;

  // ── 安全与权限 ──────────────────────────────────────────────
  static const lock = DshGlyphs.oaPaw;
  static const lockActive = DshGlyphs.oaStarOfLife;
  static const unlock = DshGlyphs.oaStarOfLife;

  /// 凭据只留在本机。
  static const localOnly = DshGlyphs.oaStarOfLife;
  static const approval = DshGlyphs.oaStarOfLife;
  static const securityWarning = DshGlyphs.oaStarOfLife;
  static const permissions = DshGlyphs.oaWrench;
  static const safeMode = DshGlyphs.oaStarOfLife;
  static const verified = DshGlyphs.oaStarOfLife;
  static const fingerprint = DshGlyphs.oaStarOfLife;
  static const apiKey = DshGlyphs.oaStarOfLife;
  static const noApiKey = DshGlyphs.oaStarOfLife;
  static const autoApprove = DshGlyphs.oaStarOfLife;

  // ── 文件与内容 ──────────────────────────────────────────────
  static const folder = DshGlyphs.oaFolder;

  /// 带分组色的实心文件夹(抽屉文件夹、文件列表)。
  static const folderMark = DshGlyphs.oaFolder;
  static const folderOpen = DshGlyphs.oaFolder;
  static const workspace = DshGlyphs.oaFolder;
  static const workspaceGroup = DshGlyphs.oaFolder;
  static const defaultFolder = DshGlyphs.oaFolder;
  static const sharedStorage = DshGlyphs.oaGlobe;
  static const home = DshGlyphs.oaStarOfLife;
  static const phoneStorage = DshGlyphs.oaStarOfLife;
  static const downloads = DshGlyphs.oaGlobe;
  static const document = DshGlyphs.oaFolder;
  static const instructions = DshGlyphs.oaStarOfLife;
  static const file = DshGlyphs.oaFolder;
  static const fileNew = DshGlyphs.oaFolder;
  static const diff = DshGlyphs.oaStarOfLife;
  static const pdf = DshGlyphs.oaFolder;
  static const image = DshGlyphs.oaPhoto;
  static const videoFile = DshGlyphs.oaFolder;
  static const video = DshGlyphs.oaPhoto;
  static const audioFile = DshGlyphs.oaFolder;
  static const audio = DshGlyphs.oaVoiceButton;
  static const zip = DshGlyphs.oaStarOfLife;
  static const slides = DshGlyphs.oaStarOfLife;
  static const spreadsheet = DshGlyphs.oaFolder;
  static const article = DshGlyphs.oaStarOfLife;
  static const plainText = DshGlyphs.oaFolder;
  static const summary = DshGlyphs.oaStarOfLife;
  static const code = DshGlyphs.oaBraces;
  static const diagram = DshGlyphs.oaStarOfLife;
  static const artifacts = DshGlyphs.oaStarOfLife;
  static const shareBundle = DshGlyphs.oaGlobe;

  /// 文件还在生成。
  static const generating = DshGlyphs.oaStarOfLife;

  // ── 图像与视频生成(docs/design/media-generation.md)──────────────
  /// ＋ 面板的「生成」磁贴、设置 › 图像与视频。
  static const generateMedia = DshGlyphs.oaPhoto;

  /// 模式胶囊、参数弹层:图像 / 视频。
  static const generateImage = DshGlyphs.oaPhoto;
  static const generateVideo = DshGlyphs.oaPhoto;

  /// 查看器:「详情」。
  static const mediaDetails = DshGlyphs.oaPhoto;

  /// 查看器:变体、编辑、放大。
  static const mediaVary = DshGlyphs.oaPhoto;
  static const mediaEdit = DshGlyphs.oaPhoto;
  static const mediaUpscale = DshGlyphs.oaPhoto;

  /// 权限胶囊:比工作区内修改更宽松。
  static const permissionRisky = DshGlyphs.oaStarOfLife;
  static const web = DshGlyphs.oaGlobe;
  static const readText = DshGlyphs.oaFolder;

  // ── 功能 ────────────────────────────────────────────────────
  static const terminal = DshGlyphs.oaTerminal;
  static const plugin = DshGlyphs.oaTerminal;
  static const pluginInventory = DshGlyphs.oaTerminal;
  static const skill = DshGlyphs.oaCodex;
  static const model = DshGlyphs.oaBrain;
  static const providers = DshGlyphs.oaStarOfLife;

  /// 模型列表里的一个模型。
  static const modelItem = DshGlyphs.oaBrain;
  static const subagents = DshGlyphs.oaStarOfLife;
  static const workflow = DshGlyphs.oaStarOfLife;
  static const todo = DshGlyphs.oaStarOfLife;
  static const goal = DshGlyphs.oaHeart;
  static const plan = DshGlyphs.oaNotebook;
  static const planMode = DshGlyphs.oaStarOfLife;
  static const jobs = DshGlyphs.oaStarOfLife;
  static const automation = DshGlyphs.oaStarOfLife;
  static const recurring = DshGlyphs.oaStarOfLife;
  static const scheduled = DshGlyphs.oaBrain;
  static const time = DshGlyphs.oaBrain;
  static const timeZone = DshGlyphs.oaBrain;
  static const commandTimeout = DshGlyphs.oaBrain;
  static const agentLoop = DshGlyphs.oaStarOfLife;
  static const webSearch = DshGlyphs.oaPhoto;
  static const webApp = DshGlyphs.oaGlobe;
  static const mention = DshGlyphs.oaChatBubble;
  static const translate = DshGlyphs.oaStarOfLife;
  static const history = DshGlyphs.oaFolder;
  static const sessionDetails = DshGlyphs.oaStarOfLife;
  static const trajectory = DshGlyphs.oaStarOfLife;
  static const diagnostics = DshGlyphs.oaStarOfLife;
  static const cordis = DshGlyphs.oaStarOfLife;

  /// Bot 发来的可交互面板。
  static const panel = DshGlyphs.oaStarOfLife;
  static const feedback = DshGlyphs.oaArrowRight;
  static const tool = DshGlyphs.oaTerminal;
  static const tip = DshGlyphs.oaStarOfLife;

  /// 伙伴小屋: she now and then asks you to rest with her (companion_page.dart).
  static const companionInvite = DshGlyphs.oaPaw;

  /// 伙伴小屋: her words read aloud (companion_voice.dart). Not the microphone: that is the person's voice.
  static const companionVoice = DshGlyphs.oaPaw;

  /// 「问 AI」: a question about the app for the agent (ui/common/ask_ai.dart).
  static const askAi = DshGlyphs.oaStarOfLife;

  /// 「给 dsh-go 点个 star」: the project on GitHub (ui/star/).
  static const starProject = DshGlyphs.oaStarOfLife;
  static const important = DshGlyphs.oaStarOfLife;
  static const theme = DshGlyphs.oaPalette;
  static const textSize = DshGlyphs.oaFolder;
  static const phoneLayout = DshGlyphs.oaStarOfLife;
  static const account = DshGlyphs.oaPaw;
  static const profile = DshGlyphs.oaPaw;
  static const avatar = DshGlyphs.oaPaw;
  static const balance = DshGlyphs.oaBarChart;
  static const shareConfig = DshGlyphs.oaWrench;
  static const chart = DshGlyphs.oaBarChart;

  /// 设置 › 宠物.
  static const pet = DshGlyphs.oaPaw;

  /// 设置 › 隐私与分享.
  static const privacy = DshGlyphs.oaStarOfLife;

  // ── 手机操控 ────────────────────────────────────────────────
  static const phoneControl = DshGlyphs.oaStarOfLife;
  static const readScreen = DshGlyphs.oaFolder;
  static const askFirst = DshGlyphs.oaStarOfLife;
  static const askPerTask = DshGlyphs.oaStarOfLife;
  static const noConfirm = DshGlyphs.oaStarOfLife;
  static const appRules = DshGlyphs.oaStarOfLife;
  static const dndMode = DshGlyphs.oaStarOfLife;
  static const keepAlive = DshGlyphs.oaStarOfLife;
  static const operate = DshGlyphs.oaStarOfLife;
  static const alarmClock = DshGlyphs.oaBrain;
  static const returnToApp = DshGlyphs.oaStarOfLife;
  static const backgroundPrompt = DshGlyphs.oaArrowRight;
  static const overlayOpacity = DshGlyphs.oaStarOfLife;
  static const overlayBall = DshGlyphs.oaStarOfLife;

  /// 解除限制, its 「已解除限制」 tag, and its three rules.
  static const unlocks = DshGlyphs.oaStarOfLife;
  static const unlockSystem = DshGlyphs.oaStarOfLife;
  static const unlockSecrets = DshGlyphs.oaStarOfLife;
  static const unlockOwnApp = DshGlyphs.oaStarOfLife;

  /// 解除限制's confirmation page: what can go wrong, and the disclaimer.
  static const riskWarning = DshGlyphs.oaStarOfLife;

  // ── 系统权限(首次启动的「按功能开启」与 设置 › 系统权限)──────
  static const systemAccess = DshGlyphs.oaStarOfLife;
  static const fileAccess = DshGlyphs.oaFolder;
  static const accessibility = DshGlyphs.oaStarOfLife;
  static const overlayPermission = DshGlyphs.oaStarOfLife;
  static const highPower = DshGlyphs.oaGlobe;
  static const autostart = DshGlyphs.oaStarOfLife;
  static const backgroundPopUp = DshGlyphs.oaArrowRight;

  // ── DS Bot 与群聊 ───────────────────────────────────────────
  static const bot = DshGlyphs.oaPaw;
  static const groupChat = DshGlyphs.oaChatBubble;
  static const newGroupChat = DshGlyphs.oaChatBubble;
  static const addMember = DshGlyphs.oaPencil;
  static const removeMember = DshGlyphs.oaArrowRight;
  static const makeAdmin = DshGlyphs.oaStarOfLife;
  static const team = DshGlyphs.oaPaw;
  static const conversations = DshGlyphs.oaChatBubble;
  static const chat = DshGlyphs.oaChatBubble;
  static const announcement = DshGlyphs.oaStarOfLife;
  static const nameTag = DshGlyphs.oaStarOfLife;
  static const botRole = DshGlyphs.oaPaw;
  static const color = DshGlyphs.oaPhoto;
  static const today = DshGlyphs.oaStarOfLife;
  static const lastWeek = DshGlyphs.oaStarOfLife;
  static const lastMonth = DshGlyphs.oaStarOfLife;
  static const fullLog = DshGlyphs.oaFolder;
  static const working = DshGlyphs.oaStarOfLife;
  static const presetStandard = DshGlyphs.oaStarOfLife;
  static const presetMinimal = DshGlyphs.oaStarOfLife;
  static const presetCordis = DshGlyphs.oaStarOfLife;
  static const presetPtc = DshGlyphs.oaStarOfLife;

  // ── 论坛与社区 ──────────────────────────────────────────────
  static const forum = DshGlyphs.oaChatBubble;
  static const community = DshGlyphs.oaStarOfLife;
  static const newTopic = DshGlyphs.oaPencil;
  static const moved = DshGlyphs.oaArrowRight;
  static const invite = DshGlyphs.oaPaw;
  static const reminder = DshGlyphs.oaBrain;
  static const reaction = DshGlyphs.oaStarOfLife;
  static const badgeEarned = DshGlyphs.oaStarOfLife;
  static const poll = DshGlyphs.oaStarOfLife;
  static const playVideo = DshGlyphs.oaPhoto;
  static const mail = DshGlyphs.oaChatBubble;
  static const write = DshGlyphs.oaPencil;
  static const featured = DshGlyphs.oaStarOfLife;
  static const bug = DshGlyphs.oaFlask;
  static const school = DshGlyphs.oaGraduationCap;
  static const travel = DshGlyphs.oaSuitcase;
  static const calendar = DshGlyphs.oaBrain;

  /// 社区里的外部渠道。
  static const wechat = DshGlyphs.oaChatBubble;
  static const qq = DshGlyphs.oaStarOfLife;
  static const telegram = DshGlyphs.oaStarOfLife;
  static const discord = DshGlyphs.oaStarOfLife;

  // ── OpenAI `ds_*` 图标集（从官方 APK 反编译实测，24×24dp viewport） ──
  // 见 docs/chatgpt-apk-spec.md。生成：python3 tool/make_icon_font.py
  static const oaBrain = DshGlyphs.oaBrain;
  static const oaCamera = DshGlyphs.oaCamera;
  static const oaPhoto = DshGlyphs.oaPhoto;
  static const oaPhotoOnSquare = DshGlyphs.oaPhotoOnSquare;
  static const oaFolder = DshGlyphs.oaFolder;
  static const oaPencil = DshGlyphs.oaPencil;
  static const oaPencilBrush = DshGlyphs.oaPencilBrush;
  static const oaMicrophone = DshGlyphs.oaMicrophone;
  static const oaMicrophoneFill = DshGlyphs.oaMicrophoneFill;
  static const oaVoiceButton = DshGlyphs.oaVoiceButton;
  static const oaStop = DshGlyphs.oaStop;
  static const oaChatBubble = DshGlyphs.oaChatBubble;
  static const oaShare = DshGlyphs.oaShare;
  static const oaSend = DshGlyphs.oaSend;
  static const oaGlobe = DshGlyphs.oaGlobe;
  static const oaCodex = DshGlyphs.oaCodex;
  static const oaTerminal = DshGlyphs.oaTerminal;
  static const oaBook = DshGlyphs.oaBook;
  static const oaBarChart = DshGlyphs.oaBarChart;
  static const oaWrench = DshGlyphs.oaWrench;
  static const oaPalette = DshGlyphs.oaPalette;
  static const oaPersonalization = DshGlyphs.oaPersonalization;
  static const oaStarOfLife = DshGlyphs.oaStarOfLife;
  static const oaOpenai = DshGlyphs.oaOpenai;
  static const oaSuitcase = DshGlyphs.oaSuitcase;
  static const oaMusic = DshGlyphs.oaMusic;
  static const oaPlane = DshGlyphs.oaPlane;
}
