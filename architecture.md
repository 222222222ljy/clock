# 数字时钟 — 系统架构框图

> 基于 2K22 数电大作业 Verilog 实现

---

## 1. `clock_timer` — 时钟分频器

```mermaid
flowchart LR
    subgraph CT["clock_timer"]
        direction TB
        CORE["计数器 cnt[31:0]<br/>每个 clk 上升沿 +1"]
        COMP1["cnt == div ?"]
        COMP2["cnt == div/2 ?"]
        CORE --> COMP1 & COMP2
        COMP1 -->|"是: upo取反, cnt清零"| OUT
        COMP2 -->|"是: upo取反"| OUT
    end

    CLK_IN["clk<br/>输入时钟<br/>12MHz (系统晶振)"] -->|"上升沿触发"| CORE
    DIV_IN["div[31:0]<br/>分频系数<br/>freq=12_000_000 → 1Hz<br/>freq/10 → 10Hz"] -->|"计数目标"| COMP1 & COMP2

    CT -->|"upo<br/>分频输出<br/>50% 占空比方波"| UPO_OUT["→ clock_number.upi"]

    style CT fill:#fff3e0,stroke:#f57c00,stroke-width:2
    style CLK_IN fill:#e1f5fe,stroke:#0288d1
    style DIV_IN fill:#e1f5fe,stroke:#0288d1
    style UPO_OUT fill:#ffebee,stroke:#c62828
```

---

## 2. `clock_number` — 通用计数器

```mermaid
flowchart LR
    subgraph CN["clock_number"]
        direction TB
        LOGIC["计数逻辑<br/>(每个 clk_sys 上升沿)"]
        DECODE{"val 模式解码"}
        EDGE{"上升沿检测<br/>upil ← upi (延迟一拍)"}

        DECODE -->|"2'b11<br/>自动进位模式"| EDGE
        EDGE -->|"upi=1 & upil=0"| INC1["now ← now+1"]
        DECODE -->|"2'b10<br/>手动加"| INC2["now ← now+1"]
        DECODE -->|"2'b01<br/>手动减"| DEC["now ← now-1"]

        INC1 & INC2 & DEC --> BOUND{"边界处理"}
        BOUND -->|"now == term"| CLR["now ← 0<br/>upo 取反 (产生进位)"]
        BOUND -->|"now == 255"| SAT["now ← term-1<br/>(防负溢出)"]
    end

    CLK_SYS["clk_sys<br/>10Hz 系统反应时钟"] --> LOGIC
    VAL["val[1:0]<br/>模式选择<br/>11=自动进位<br/>10=手动加, 01=手动减"] --> DECODE
    TERM["term[7:0]<br/>计数模值<br/>60 (分/秒) / 24 (时)"] --> BOUND
    UPI["upi<br/>输入进位脉冲<br/>(来自低位)"] --> EDGE

    CN --> NOW_OUT["now[7:0]<br/>当前计数值 (二进制)<br/>→ display / 高位 upi"]
    CN --> UPO_OUT["upo<br/>进位输出<br/>(达到 term 时触发)"]

    style CN fill:#e8f5e9,stroke:#388e3c,stroke-width:2
    style CLK_SYS fill:#e1f5fe,stroke:#0288d1
    style VAL fill:#e1f5fe,stroke:#0288d1
    style TERM fill:#e1f5fe,stroke:#0288d1
    style UPI fill:#e1f5fe,stroke:#0288d1
    style NOW_OUT fill:#ffebee,stroke:#c62828
    style UPO_OUT fill:#ffebee,stroke:#c62828
```

---

## 3. `bin2bcd` — 二进制转 BCD

```mermaid
flowchart LR
    subgraph B2B["bin2bcd"]
        direction TB
        IDLE{"busy 标志"}
        IDLE -->|"0: 空闲"| LOAD["shift ← {8'b0, bin}<br/>cnt ← 0<br/>busy ← 1"]
        IDLE -->|"1: 工作中"| CHECK{"shift[11:8]>=5<br/>或 shift[15:12]>=5?"}
        CHECK -->|"是: +3 调整"| ADJ["对应半字节 +3"]
        CHECK -->|"否"| SKIP
        ADJ --> SHIFT["shift ← shift << 1<br/>cnt ← cnt + 1"]
        SKIP --> SHIFT
        SHIFT --> DONE?{"cnt == 8?<br/>(8次移位完成)"}
        DONE? -->|"否"| IDLE
        DONE? -->|"是"| FINISH["bcd ← shift[15:8]<br/>done ← 1<br/>busy ← 0"]
    end

    CLK_BIN["clk<br/>系统时钟"] --> IDLE
    BIN["bin[7:0]<br/>二进制输入<br/>0~59 (分/秒) / 0~23 (时)"] --> LOAD

    B2B --> BCD["bcd[7:0]<br/>BCD码输出<br/>高4位=十位, 低4位=个位"]
    B2B --> DONE_SIG["done<br/>转换完成标志"]

    style B2B fill:#f3e5f5,stroke:#7b1fa2,stroke-width:2
    style CLK_BIN fill:#e1f5fe,stroke:#0288d1
    style BIN fill:#e1f5fe,stroke:#0288d1
    style BCD fill:#ffebee,stroke:#c62828
    style DONE_SIG fill:#ffebee,stroke:#c62828
```

---

## 4. `seg14` — BCD 转 14段码

```mermaid
flowchart LR
    subgraph SEG["seg14"]
        direction TB
        HIGH["取十位<br/>digit[7:4]"]
        LOW["取个位<br/>digit[3:0]"]
        LUT_H["查表 0→9<br/>输出对应7段码"]
        LUT_L["查表 0→9<br/>输出对应7段码"]
        INV["seg ← ~seg<br/>(LED 反向导通)"]

        HIGH --> LUT_H
        LOW --> LUT_L
        LUT_H & LUT_L --> INV
    end

    DIGIT["digit[7:0]<br/>BCD 输入"] --> HIGH & LOW

    SEG --> SEG_OUT["seg[13:0]<br/>14段码输出<br/>seg[13:7]=十位, seg[6:0]=个位<br/>→ display 寄存器"]

    style SEG fill:#f3e5f5,stroke:#7b1fa2,stroke-width:2
    style DIGIT fill:#e1f5fe,stroke:#0288d1
    style SEG_OUT fill:#ffebee,stroke:#c62828
```

---

## 5. `display` — 显示控制器

```mermaid
flowchart LR
    subgraph DSP["display"]
        direction TB
        B2B_HR["bin2bcd<br/>时: 二进制→BCD"]
        B2B_MN["bin2bcd<br/>分: 二进制→BCD"]
        MUX{"二选一选通器<br/>~K ? hour_bcd : min_bcd"}
        SEG14["seg14<br/>BCD → 14段码"]
        REG["寄存器<br/>(clk 上升沿锁存)"]

        B2B_HR --> MUX
        B2B_MN --> MUX
        MUX --> SEG14
        SEG14 --> REG
    end

    CLK_DISP["clk<br/>系统时钟 (12MHz)<br/>用于快速显示切换"] --> B2B_HR & B2B_MN & REG
    NOW_HR["now_hr[7:0]<br/>时计数值 (二进制)"] --> B2B_HR
    NOW_MN["now_mn[7:0]<br/>分计数值 (二进制)"] --> B2B_MN
    K_SEL["K[3]<br/>显示选择<br/>0 = 显示分钟<br/>1 = 显示小时"] --> MUX

    DSP --> SEQ["seq[13:0]<br/>→ 14段数码管"]

    style DSP fill:#bbdefb,stroke:#1565c0,stroke-width:2
    style CLK_DISP fill:#e1f5fe,stroke:#0288d1
    style NOW_HR fill:#e1f5fe,stroke:#0288d1
    style NOW_MN fill:#e1f5fe,stroke:#0288d1
    style K_SEL fill:#e1f5fe,stroke:#0288d1
    style SEQ fill:#ffebee,stroke:#c62828
```

---

## 6. `tik` — 整点报时控制器（time_talker）

```mermaid
flowchart LR
    subgraph TIK["tik"]
        direction TB
        TRIG{"上升沿检测<br/>in=1 & inl=0"}
        TRIG -->|"触发"| LOAD["res ← num<br/>(加载闪烁次数)"]
        LOAD --> DEC?{"res > 0?"}
        DEC? -->|"是: 闪灯中"| TIMER["now ← now+1<br/>(计时)"]
        TIMER --> HALF?{"now == freq/2?"}
        HALF? -->|"是"| ON["out ← 63<br/>(全亮)"]
        TIMER --> FULL?{"now == freq?"}
        FULL? -->|"是: 1秒到"| FLASH["out ← K<br/>res ← res-1<br/>now ← 0"]
        DEC? -->|"否: 常亮"| STEADY["out ← K<br/>(保持模式)"]
    end

    CLK_TIK["clk_sys<br/>10Hz 系统时钟"] --> TIMER
    IN_TIK["in<br/>触发信号<br/>= upo_mn (分→时进位)"] --> TRIG
    NUM["num[7:0]<br/>闪烁次数<br/>= now_hr (小时数)"] --> LOAD
    MODE["K[6:0]<br/>常亮模式<br/>= RGBmode"] --> STEADY

    TIK --> OUT_TIK["out[5:0]<br/>RGB 灯控输出<br/>闪灯: 交替 63/K<br/>常亮: = K"]

    style TIK fill:#e0f7fa,stroke:#00838f,stroke-width:2
    style CLK_TIK fill:#e1f5fe,stroke:#0288d1
    style IN_TIK fill:#e1f5fe,stroke:#0288d1
    style NUM fill:#e1f5fe,stroke:#0288d1
    style MODE fill:#e1f5fe,stroke:#0288d1
    style OUT_TIK fill:#ffebee,stroke:#c62828
```

---

## 7. `mode_change` — RGB 模式切换

```mermaid
flowchart LR
    subgraph MC["mode_change"]
        direction TB
        EDGE{"K == 0?<br/>(按键按下)"}
        EDGE -->|"是: 模式+1"| INC["out ← out+1"]
        INC --> WRAP{"out == 63?"}
        WRAP -->|"是: 循环"| RESET["out ← 0"]
    end

    CLK_MC["clk_sys<br/>10Hz 系统时钟"] --> EDGE
    K_MC["K[2]<br/>模式切换键"] --> EDGE

    MC --> OUT_MC["out[5:0]<br/>RGB 模式<br/>0~62 共 63 种模式<br/>→ tik.K"]

    style MC fill:#e0f7fa,stroke:#00838f,stroke-width:2
    style CLK_MC fill:#e1f5fe,stroke:#0288d1
    style K_MC fill:#e1f5fe,stroke:#0288d1
    style OUT_MC fill:#ffebee,stroke:#c62828
```

---

## 8. `top`（完整版）— 含整点报时的顶层系统

```mermaid
flowchart TB
    subgraph TOP2["top (含整点报时)"]
        direction TB

        subgraph CLK2["① 时钟分频"]
            CT1["clock_timer<br/>div=freq/10=1.2MHz<br/>→ 10Hz (clk_in)"]
            CT2["clock_timer<br/>div=freq=12MHz<br/>→ 1Hz (clk)"]
        end

        subgraph CNT2["② 计时级联"]
            SE2["clock_number<br/>term=60<br/>秒"]
            MN2["clock_number<br/>term=60<br/>分"]
            HR2["clock_number<br/>term=24<br/>时"]
        end

        subgraph TALK["③ 整点报时"]
            MODE["mode_change<br/>K[2] 切换<br/>→ RGBmode[5:0]"]
            TIK["tik<br/>upo_mn 触发<br/>→ RGB[5:0]"]
        end

        subgraph DSP2["④ 显示"]
            DISP2["display<br/>→ seq[13:0]"]
        end
    end

    CLK_SYS2["clk_sys<br/>12MHz"] --> CT1 & CT2
    K2["K[3:0]<br/>按键"] --> CNT2 & TALK & DSP2

    CT1 -->|"10Hz<br/>系统反应时钟"| CNT2 & TALK
    CT2 -->|"1Hz"| SE2
    SE2 -->|"进位"| MN2
    MN2 -->|"upo_mn"| HR2
    MN2 -->|"upo_mn"| TIK
    HR2 -->|"now_hr"| TIK

    TIK -->|"RGB[5:0]"| RGB_OUT["RGB LED 灯"]
    DSP2 -->|"seq[13:0]"| SEQ2["14段数码管"]
    CT2 -->|"clk (1Hz)"| SEC_OUT["秒闪 LED"]

    style TOP2 fill:#f5f5f5,stroke:#333,stroke-width:3
    style CLK2 fill:#fff3e0,stroke:#f57c00
    style CNT2 fill:#e8f5e9,stroke:#388e3c
    style TALK fill:#e0f7fa,stroke:#00838f
    style DSP2 fill:#f3e5f5,stroke:#7b1fa2
```

## 信号汇总（整点报时补充）

| 信号 | 位宽 | 方向 | 说明 |
|------|------|------|------|
| `RGB[5:0]` | 6 | 输出 | RGB LED 控制 (共 63 种模式) |
| `RGBmode[5:0]` | 6 | 内部 | 当前闪灯模式 (K[2] 切换) |
| `in` | 1 | 输入 | tik 触发信号 (= upo_mn) |
| `num[7:0]` | 8 | 输入 | tik 闪烁次数 (= now_hr) |
| `res[5:0]` | 6 | 内部 | tik 剩余闪烁次数 |
| `K[2]` | 1 | 输入 | 模式切换键 (RGB 循环) |

---

## 图例

| 颜色 | 含义 |
|------|------|
| 🔵 浅蓝 | **输入信号** — 来自外部或上层模块 |
| 🟠 橙色 | **时钟分频模块** |
| 🟢 绿色 | **计数器模块** |
| 🟣 紫色 | **显示处理模块** |
| 🔴 浅红 | **输出信号** — 送到外部或下层模块 |
| 🟡 米黄 | **控制逻辑** |
| ⚪ 灰色 | **顶层模块** (系统整合) |

## 信号汇总

| 信号 | 位宽 | 方向 | 说明 |
|------|------|------|------|
| `clk_sys` | 1 | 输入 | 12MHz 系统晶振时钟 |
| `K[3:0]` | 4 | 输入 | 按键: K[1:0]=加减, K[3]=时/分切换 |
| `clk` | 1 | 输出 | 1Hz 方波 (秒闪) |
| `seq[13:0]` | 14 | 输出 | 14段数码管显示 |
| `dig[1:0]` | 2 | 输出 | 数码管位选 (固定 2'b00) |
| `upi` | 1 | 内部 | 进位输入 (来自低位) |
| `upo` | 1 | 内部 | 进位输出 (到高位) |
| `now[7:0]` | 8 | 内部 | 当前计数值 (二进制) |
| `val[1:0]` | 2 | 内部 | 模式: 11=自动, 10=加, 01=减 |
| `term[7:0]` | 8 | 参数 | 计数模值: 60/24 |
| `div[31:0]` | 32 | 参数 | 分频系数 |
