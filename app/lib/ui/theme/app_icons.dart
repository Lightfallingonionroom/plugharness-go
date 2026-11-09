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
  static const back = DshGlyphs.cgChevronLeftLg;
  static const forward = DshGlyphs.cgChevronRightLg;
  static const close = DshGlyphs.cgXmarkLg;
  static const menu = DshGlyphs.cgSidebarMenu;
  static const more = DshGlyphs.cgEllipsisHorizontal;

  /// 系统「⋮」菜单(只在引导里指给用户看)。
  static const moreVertical = DshGlyphs.cgEllipsisVertical;

  /// 行尾「进入」、面包屑分隔。
  static const disclosure = DshGlyphs.cgChevronRightLg;
  static const expand = DshGlyphs.cgChevronDownMd;
  static const collapse = DshGlyphs.cgChevronUpMd;

  /// 可切换的选择器:主机、工作区、余额。
  static const dropdown = DshGlyphs.cgChevronDownMd;
  static const openExternal = DshGlyphs.cgGlobe;
  static const openLink = DshGlyphs.cgGlobe;
  static const openWith = DshGlyphs.dotsNine;
  static const allFeatures = DshGlyphs.dotsNine;
  static const browser = DshGlyphs.cgGlobe;
  static const scrollToBottom = DshGlyphs.cgArrowDownLg;
  static const sidebar = DshGlyphs.cgSidebarMenu;
  static const dragHandle = DshGlyphs.dotsSixVertical;
  static const swap = DshGlyphs.arrowsLeftRight;

  /// 终端方向键、补全面板里的回车提示。
  static const keyUp = DshGlyphs.caretUp;
  static const keyDown = DshGlyphs.caretDown;
  static const keyLeft = DshGlyphs.caretLeft;
  static const keyRight = DshGlyphs.caretRight;
  static const enterKey = DshGlyphs.arrowElbowDownLeft;

  /// 翻页(插件轮播):上一页 / 下一页。上一页在从右往左的语言里要镜像着画。
  static const pagePrevious = DshGlyphs.caretLeft;
  static const pageNext = DshGlyphs.caretRight;

  // ── 输入框 ──────────────────────────────────────────────────
  static const send = DshGlyphs.cgArrowUpLgButton;

  /// 输入框圆键里的停止(生成、语音):实心方块。
  static const stopGenerating = DshGlyphs.cgStopFill;
  static const voice = DshGlyphs.cgMicrophone;

  /// 插话:本轮中途送进去。
  static const steer = DshGlyphs.arrowElbowDownRight;

  /// 排队:本轮结束后发送。
  static const queued = DshGlyphs.cgClock;

  /// 打断:停掉本轮再发。
  static const interrupt = DshGlyphs.stopCircle;
  static const camera = DshGlyphs.cgCamera;
  static const gallery = DshGlyphs.cgPhoto;
  static const files = DshGlyphs.cgPaperclip;
  static const addImage = DshGlyphs.cgPhotoOnTiltedSquare;

  /// 「传文件到电脑」 (Remote workspace upload).
  static const uploadToHost = DshGlyphs.boxArrowUp;

  // ── 消息操作 ────────────────────────────────────────────────
  static const copy = DshGlyphs.copy;
  static const quote = DshGlyphs.quotes;
  static const share = DshGlyphs.cgShareAndroid;
  static const qrCode = DshGlyphs.cgBraces;
  static const shareImage = DshGlyphs.image;

  /// 分享面板的另两个去向:文件、文字。
  static const shareFile = DshGlyphs.fileText;
  static const shareText = DshGlyphs.textAlignLeft;

  /// 刚生成的链接上的「停止分享」。
  static const stopSharing = DshGlyphs.linkBreak;

  /// 分享出去的内容已隐藏密钥和个人路径。
  static const redacted = DshGlyphs.shieldCheck;

  static const selectText = DshGlyphs.textT;
  static const fork = DshGlyphs.cgArrowBranch;
  static const regenerate = DshGlyphs.cgArrowRotateClockwise;
  static const edit = DshGlyphs.cgPencil;
  static const reply = DshGlyphs.arrowBendUpLeft;

  /// 代码、diff 的自动换行开关。
  static const wrapLines = DshGlyphs.textWrap;
  static const save = DshGlyphs.downloadSimple;
  static const preview = DshGlyphs.eye;

  /// 操作完成的回执:已复制、已保存。
  static const done = DshGlyphs.cgCheckmarkLg;

  // ── 通用操作 ────────────────────────────────────────────────
  static const add = DshGlyphs.cgPlusLg;

  /// 输入框尾部的「添加这一项」。
  static const addEntry = DshGlyphs.cgPlusMd;
  static const increment = DshGlyphs.cgBarChart;
  static const decrement = DshGlyphs.minus;
  static const remove = DshGlyphs.minusCircle;
  static const rename = DshGlyphs.pencilSimpleLine;
  static const delete = DshGlyphs.cgTrash;

  /// 文件已被删掉的占位。
  static const deleted = DshGlyphs.trash;

  /// 清空输入框。
  static const clear = DshGlyphs.xCircleFill;
  static const clearAll = DshGlyphs.broom;
  static const paste = DshGlyphs.clipboard;
  static const download = DshGlyphs.downloadSimple;
  static const refresh = DshGlyphs.cgArrowRotateClockwise;
  static const retry = DshGlyphs.cgArrowRotateClockwise;
  static const restart = DshGlyphs.arrowCounterClockwise;
  static const search = DshGlyphs.cgMagnifyingGlassMd;
  static const configure = DshGlyphs.cgGear;
  static const settings = DshGlyphs.cgGear;
  static const link = DshGlyphs.cgBraces;
  static const showSecret = DshGlyphs.eye;
  static const hideSecret = DshGlyphs.eyeSlash;
  static const newChat = DshGlyphs.cgSquareAndPencil;
  static const newFolder = DshGlyphs.cgFolderBadgePlus;
  static const newPost = DshGlyphs.cgSquareAndPencil;
  static const moveToFolder = DshGlyphs.cgFolderBadgeArrowDown;
  static const multiSelect = DshGlyphs.checkCircle;
  static const archive = DshGlyphs.cgArchive;
  static const unarchive = DshGlyphs.cgArchive;
  static const exportLog = DshGlyphs.archive;
  static const pin = DshGlyphs.cgPin;
  static const pinActive = DshGlyphs.cgPinFill;
  static const logout = DshGlyphs.signOut;
  static const power = DshGlyphs.power;

  /// 行、胶囊里的启动 / 暂停 / 停止:和别的操作一样用描边。
  static const play = DshGlyphs.play;
  static const pause = DshGlyphs.pause;
  static const stop = DshGlyphs.cgStopFill;

  /// 回放的播放键:媒体控件按惯例用实心。
  static const mediaPlay = DshGlyphs.cgCirclePlayFill;
  static const mediaPause = DshGlyphs.cgCirclePause;

  /// 回放播完后从头再放。
  static const replay = DshGlyphs.arrowCounterClockwise;

  /// 回放页的「全文」。
  static const fullText = DshGlyphs.article;
  static const enterPath = DshGlyphs.cursorText;
  static const viewConfig = DshGlyphs.fileText;

  /// 拿一条要在终端里跑的命令。
  static const command = DshGlyphs.cgTerminal;
  static const fetchModels = DshGlyphs.cgTerminal;
  static const testConnection = DshGlyphs.broadcast;
  static const markAllRead = DshGlyphs.checks;
  static const manageFolders = DshGlyphs.cgFolder;

  /// /compact:压缩上下文。
  static const compact = DshGlyphs.cgBraces;

  /// 完成后把思考与工具调用收成一行。
  static const foldTurns = DshGlyphs.arrowsInLineVertical;

  // ── 选择与开关(选中 / 开启态用 Fill)──────────────────────
  /// 列表里当前选中的那一项。
  static const selected = DshGlyphs.cgCircleCheckmark;
  static const allowed = DshGlyphs.cgCircleCheckmark;
  static const radioOn = DshGlyphs.cgCircleCheckmarkFill;
  static const radioOff = DshGlyphs.cgCircle;
  static const checkboxOn = DshGlyphs.cgSquareCheckmark;
  static const checkboxOff = DshGlyphs.cgSquare;
  static const isDefault = DshGlyphs.checkCircleFill;
  static const setDefault = DshGlyphs.checkCircle;
  static const favorite = DshGlyphs.cgHeart;
  static const favoriteActive = DshGlyphs.cgStarFill;
  static const bookmark = DshGlyphs.cgBookmark;
  static const bookmarkActive = DshGlyphs.cgBookmarkFill;
  static const postLike = DshGlyphs.cgThumbUp;
  static const postLikeActive = DshGlyphs.cgThumbUpFill;

  /// 回复下方的「差评」，与 [postLike] 成对。
  static const postDislike = DshGlyphs.cgThumbDown;
  static const postDislikeActive = DshGlyphs.cgThumbDownFill;

  /// 回复下方的「朗读」。
  static const readAloud = DshGlyphs.cgSpeakerSoundWave2;
  static const notifications = DshGlyphs.cgBell;
  static const notificationsOn = DshGlyphs.cgBell;
  static const notificationsOff = DshGlyphs.cgBellSlash;

  // ── 状态 ────────────────────────────────────────────────────
  static const success = DshGlyphs.cgCircleCheckmark;
  static const completed = DshGlyphs.cgCircleCheckmark;
  static const error = DshGlyphs.cgCircleExclamationmark;
  static const warning = DshGlyphs.cgTriangleExclamationmark;
  static const info = DshGlyphs.cgCircleInfo;
  static const question = DshGlyphs.cgCircleInfo;
  static const attention = DshGlyphs.exclamationMark;
  static const caution = DshGlyphs.cgTriangleExclamationmark;

  /// 工具调用等的失败叉(配危险色)。
  static const failed = DshGlyphs.cgCircleExclamationmark;
  static const stopped = DshGlyphs.stopCircle;
  static const paused = DshGlyphs.pauseCircle;
  static const blocked = DshGlyphs.cgCircleExclamationmark;
  static const pending = DshGlyphs.circle;
  static const inProgress = DshGlyphs.radioButton;
  static const stepFailed = DshGlyphs.cgCircleExclamationmark;
  static const stepSkipped = DshGlyphs.minusCircle;
  static const loading = DshGlyphs.hourglass;
  static const waiting = DshGlyphs.hourglassHigh;
  static const running = DshGlyphs.lightning;
  static const cannotDisplay = DshGlyphs.prohibit;
  static const empty = DshGlyphs.tray;
  static const toConfirm = DshGlyphs.checkCircle;
  static const allRead = DshGlyphs.checks;
  static const outputLimit = DshGlyphs.textAlignLeft;
  static const imageBroken = DshGlyphs.cgPhoto;
  static const noResults = DshGlyphs.magnifyingGlassX;
  static const noMatches = DshGlyphs.funnelX;
  static const noFolder = DshGlyphs.folderSlash;

  /// 主机或版本不支持这项能力。
  static const unsupported = DshGlyphs.puzzlePieceSlash;
  static const taskBlocked = DshGlyphs.lockSimple;

  // ── 连接、主机与引擎 ────────────────────────────────────────
  static const offline = DshGlyphs.cloudSlash;
  static const disconnected = DshGlyphs.linkBreak;
  static const reconnecting = DshGlyphs.arrowsClockwise;
  static const engine = DshGlyphs.cgTerminal;
  static const engineStarting = DshGlyphs.cgTerminal;
  static const autoSwitch = DshGlyphs.arrowsClockwise;
  static const cloud = DshGlyphs.cgGlobe;
  static const computer = DshGlyphs.laptop;
  static const thisPhone = DshGlyphs.cgAndroid;
  static const sshHost = DshGlyphs.cgLaptopConnector;
  static const remoteHost = DshGlyphs.cgLaptopConnector;
  static const remoteHosts = DshGlyphs.cgLaptopConnector;
  static const webConsole = DshGlyphs.globe;
  static const checkUpdate = DshGlyphs.arrowCircleUp;
  static const autoUpdate = DshGlyphs.clockClockwise;

  // ── 安全与权限 ──────────────────────────────────────────────
  static const lock = DshGlyphs.cgLock;
  static const lockActive = DshGlyphs.cgLockFill;
  static const unlock = DshGlyphs.cgLock;

  /// 凭据只留在本机。
  static const localOnly = DshGlyphs.lockKey;
  static const approval = DshGlyphs.shieldWarning;
  static const securityWarning = DshGlyphs.shieldWarning;
  static const permissions = DshGlyphs.cgGear;
  static const safeMode = DshGlyphs.shieldPlus;
  static const verified = DshGlyphs.cgShieldCheckmark;
  static const fingerprint = DshGlyphs.cgPasskey;
  static const apiKey = DshGlyphs.cgKey;
  static const noApiKey = DshGlyphs.cgKey;
  static const autoApprove = DshGlyphs.checks;

  // ── 文件与内容 ──────────────────────────────────────────────
  static const folder = DshGlyphs.cgFolder;

  /// 带分组色的实心文件夹(抽屉文件夹、文件列表)。
  static const folderMark = DshGlyphs.folderFill;
  static const folderOpen = DshGlyphs.cgFolderFull;
  static const workspace = DshGlyphs.folder;
  static const workspaceGroup = DshGlyphs.folders;
  static const defaultFolder = DshGlyphs.folderStar;
  static const sharedStorage = DshGlyphs.cgGlobe;
  static const home = DshGlyphs.house;
  static const phoneStorage = DshGlyphs.deviceMobile;
  static const downloads = DshGlyphs.cgGlobe;
  static const document = DshGlyphs.fileText;
  static const instructions = DshGlyphs.fileText;
  static const file = DshGlyphs.file;
  static const fileNew = DshGlyphs.filePlus;
  static const diff = DshGlyphs.cgBraces;
  static const pdf = DshGlyphs.filePdf;
  static const image = DshGlyphs.cgPhoto;
  static const videoFile = DshGlyphs.fileVideo;
  static const video = DshGlyphs.filmStrip;
  static const audioFile = DshGlyphs.fileAudio;
  static const audio = DshGlyphs.musicNote;
  static const zip = DshGlyphs.fileZip;
  static const slides = DshGlyphs.slideshow;
  static const spreadsheet = DshGlyphs.table;
  static const article = DshGlyphs.article;
  static const plainText = DshGlyphs.textAlignLeft;
  static const summary = DshGlyphs.textAlignLeft;
  static const code = DshGlyphs.cgCode;
  static const diagram = DshGlyphs.graph;
  static const artifacts = DshGlyphs.package;
  static const shareBundle = DshGlyphs.package;

  /// 文件还在生成。
  static const generating = DshGlyphs.sparkle;

  // ── 图像与视频生成(docs/design/media-generation.md)──────────────
  /// ＋ 面板的「生成」磁贴、设置 › 图像与视频。
  static const generateMedia = DshGlyphs.magicWand;

  /// 模式胶囊、参数弹层:图像 / 视频。
  static const generateImage = DshGlyphs.image;
  static const generateVideo = DshGlyphs.filmStrip;

  /// 查看器:「详情」。
  static const mediaDetails = DshGlyphs.info;

  /// 查看器:变体、编辑、放大。
  static const mediaVary = DshGlyphs.stack;
  static const mediaEdit = DshGlyphs.pencilSimple;
  static const mediaUpscale = DshGlyphs.arrowsInLineVertical;

  /// 权限胶囊:比工作区内修改更宽松。
  static const permissionRisky = DshGlyphs.warning;
  static const web = DshGlyphs.cgGlobe;
  static const readText = DshGlyphs.note;

  // ── 功能 ────────────────────────────────────────────────────
  static const terminal = DshGlyphs.cgTerminal;
  static const plugin = DshGlyphs.cgPlugin;
  static const pluginInventory = DshGlyphs.cgPlugin;
  static const skill = DshGlyphs.bookOpen;
  static const model = DshGlyphs.cgBrain;
  static const providers = DshGlyphs.sparkle;

  /// 模型列表里的一个模型。
  static const modelItem = DshGlyphs.cgBrain;
  static const subagents = DshGlyphs.treeStructure;
  static const workflow = DshGlyphs.cgSliders;
  static const todo = DshGlyphs.listChecks;
  static const goal = DshGlyphs.cgHeart;
  static const plan = DshGlyphs.mapTrifold;
  static const planMode = DshGlyphs.mapTrifold;
  static const jobs = DshGlyphs.clipboardText;
  static const automation = DshGlyphs.alarm;
  static const recurring = DshGlyphs.repeat;
  static const scheduled = DshGlyphs.cgCalendarDay;
  static const time = DshGlyphs.cgClock;
  static const timeZone = DshGlyphs.cgClock;
  static const commandTimeout = DshGlyphs.timer;
  static const agentLoop = DshGlyphs.arrowsClockwise;
  static const webSearch = DshGlyphs.globeHemisphereWest;
  static const webApp = DshGlyphs.cgGlobe;
  static const mention = DshGlyphs.at;
  static const translate = DshGlyphs.cgGlobe;
  static const history = DshGlyphs.cgClockArrowRotateCounterclockwise;
  static const sessionDetails = DshGlyphs.chartLineUp;
  static const trajectory = DshGlyphs.path;
  static const diagnostics = DshGlyphs.stethoscope;
  static const cordis = DshGlyphs.squaresFour;

  /// Bot 发来的可交互面板。
  static const panel = DshGlyphs.squaresFour;
  static const feedback = DshGlyphs.chatCenteredDots;
  static const tool = DshGlyphs.cgTerminal;
  static const tip = DshGlyphs.lightbulb;

  /// 伙伴小屋: she now and then asks you to rest with her (companion_page.dart).
  static const companionInvite = DshGlyphs.cgPaw;

  /// 伙伴小屋: her words read aloud (companion_voice.dart). Not the microphone: that is the person's voice.
  static const companionVoice = DshGlyphs.cgPaw;

  /// 「问 AI」: a question about the app for the agent (ui/common/ask_ai.dart).
  static const askAi = DshGlyphs.sparkle;

  /// 「给 dsh-go 点个 star」: the project on GitHub (ui/star/).
  static const starProject = DshGlyphs.cgStar;
  static const important = DshGlyphs.cgStar;
  static const theme = DshGlyphs.cgPaintPalette;
  static const textSize = DshGlyphs.cgTextDashedBubble;
  static const phoneLayout = DshGlyphs.deviceMobile;
  static const account = DshGlyphs.cgCirclePerson;
  static const profile = DshGlyphs.cgCirclePerson;
  static const avatar = DshGlyphs.cgCirclePerson;
  static const balance = DshGlyphs.cgAnalytics;
  static const shareConfig = DshGlyphs.export;
  static const chart = DshGlyphs.cgBarChart;

  /// 设置 › 宠物.
  static const pet = DshGlyphs.smiley;

  /// 设置 › 隐私与分享.
  static const privacy = DshGlyphs.lockKey;

  // ── 手机操控 ────────────────────────────────────────────────
  static const phoneControl = DshGlyphs.handTap;
  static const readScreen = DshGlyphs.scan;
  static const askFirst = DshGlyphs.handPalm;
  static const askPerTask = DshGlyphs.circleHalf;
  static const noConfirm = DshGlyphs.lightning;
  static const appRules = DshGlyphs.listChecks;
  static const dndMode = DshGlyphs.stack;
  static const keepAlive = DshGlyphs.batteryPlus;
  static const operate = DshGlyphs.handPointing;
  static const alarmClock = DshGlyphs.cgAlarmClockCheckmark;
  static const returnToApp = DshGlyphs.arrowBendUpLeft;
  static const backgroundPrompt = DshGlyphs.bell;
  static const overlayOpacity = DshGlyphs.slidersHorizontal;
  static const overlayBall = DshGlyphs.radioButton;

  /// 解除限制, its 「已解除限制」 tag, and its three rules.
  static const unlocks = DshGlyphs.lockSimpleOpen;
  static const unlockSystem = DshGlyphs.gearSix;
  static const unlockSecrets = DshGlyphs.key;
  static const unlockOwnApp = DshGlyphs.browser;

  /// 解除限制's confirmation page: what can go wrong, and the disclaimer.
  static const riskWarning = DshGlyphs.shieldWarning;

  // ── 系统权限(首次启动的「按功能开启」与 设置 › 系统权限)──────
  static const systemAccess = DshGlyphs.shieldCheck;
  static const fileAccess = DshGlyphs.folderUser;
  static const accessibility = DshGlyphs.scan;
  static const overlayPermission = DshGlyphs.stack;
  static const highPower = DshGlyphs.lightning;
  static const autostart = DshGlyphs.power;
  static const backgroundPopUp = DshGlyphs.boxArrowUp;

  // ── DS Bot 与群聊 ───────────────────────────────────────────
  static const bot = DshGlyphs.robot;
  static const groupChat = DshGlyphs.chats;
  static const newGroupChat = DshGlyphs.userPlus;
  static const addMember = DshGlyphs.userPlus;
  static const removeMember = DshGlyphs.userMinus;
  static const makeAdmin = DshGlyphs.crownSimple;
  static const team = DshGlyphs.usersThree;
  static const conversations = DshGlyphs.chats;
  static const chat = DshGlyphs.chatCircle;
  static const announcement = DshGlyphs.megaphone;
  static const nameTag = DshGlyphs.identificationBadge;
  static const botRole = DshGlyphs.briefcase;
  static const color = DshGlyphs.palette;
  static const today = DshGlyphs.calendarDot;
  static const lastWeek = DshGlyphs.calendarDots;
  static const lastMonth = DshGlyphs.calendar;
  static const fullLog = DshGlyphs.receipt;
  static const working = DshGlyphs.hammer;
  static const presetStandard = DshGlyphs.wrench;
  static const presetMinimal = DshGlyphs.square;
  static const presetCordis = DshGlyphs.magicWand;
  static const presetPtc = DshGlyphs.cards;

  // ── 论坛与社区 ──────────────────────────────────────────────
  static const forum = DshGlyphs.chats;
  static const community = DshGlyphs.usersFour;
  static const newTopic = DshGlyphs.chatTeardropText;
  static const moved = DshGlyphs.folderArrowRight;
  static const invite = DshGlyphs.userPlus;
  static const reminder = DshGlyphs.cgBell;
  static const reaction = DshGlyphs.smiley;
  static const badgeEarned = DshGlyphs.medal;
  static const poll = DshGlyphs.chartBar;
  static const playVideo = DshGlyphs.playCircle;
  static const mail = DshGlyphs.envelopeSimple;
  static const write = DshGlyphs.notePencil;
  static const featured = DshGlyphs.cgStar;
  static const bug = DshGlyphs.cgWrench;
  static const school = DshGlyphs.cgBookOpen;
  static const travel = DshGlyphs.cgBriefcase;
  static const calendar = DshGlyphs.cgCalendarDay;

  /// 社区里的外部渠道。
  static const wechat = DshGlyphs.chatCircleFill;
  static const qq = DshGlyphs.usersThreeFill;
  static const telegram = DshGlyphs.paperPlaneRight;
  static const discord = DshGlyphs.headset;

  // ── 官方 ds_* 图标别名 ──────────────────────────────────────────
  // 上一版按「官方 48 个 ds_*」导出时留下的角色名，现在统一指向完整的
  // 418 个官方字形（docs/FLAGSHIP_PLAN_2026-11-07.md §0）。保留只为不
  // 破坏既有调用方。
  static const oaBrain = DshGlyphs.cgBrain;
  static const oaCamera = DshGlyphs.cgCamera;
  static const oaPhoto = DshGlyphs.cgPhoto;
  static const oaPhotoOnSquare = DshGlyphs.cgPhotoOnTiltedSquare;
  static const oaFolder = DshGlyphs.cgFolder;
  static const oaPencil = DshGlyphs.cgPencil;
  static const oaPencilBrush = DshGlyphs.cgPaintbrushOnPencil;
  static const oaMicrophone = DshGlyphs.cgMicrophone;
  static const oaMicrophoneFill = DshGlyphs.cgMicrophoneFill;
  static const oaVoiceButton = DshGlyphs.cgMicrophone;
  static const oaStop = DshGlyphs.cgStopFill;
  static const oaChatBubble = DshGlyphs.cgChatBubble;
  static const oaShare = DshGlyphs.cgShareAndroid;
  static const oaSend = DshGlyphs.cgArrowUpLgButton;
  static const oaGlobe = DshGlyphs.cgGlobe;
  static const oaCodex = DshGlyphs.cgCodex;
  static const oaTerminal = DshGlyphs.cgTerminal;
  static const oaBook = DshGlyphs.cgBook;
  static const oaBarChart = DshGlyphs.cgBarChart;
  static const oaWrench = DshGlyphs.cgWrench;
  static const oaPalette = DshGlyphs.cgPaintPalette;
  static const oaPersonalization = DshGlyphs.cgPersonalization;
  static const oaStarOfLife = DshGlyphs.cgStarOfLife;
  static const oaOpenai = DshGlyphs.cgStarOfLife;
  static const oaSuitcase = DshGlyphs.cgBriefcase;
  static const oaMusic = DshGlyphs.cgMusicNote;
  static const oaPlane = DshGlyphs.cgArrowUpLgButton;
}
