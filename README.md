# fbunch：Stata 数据驱动的群聚分析估计量

`fbunch` 是一个用于估计政策断点处群聚效应 (Bunching Estimation) 的综合性 Stata 命令。它支持 Kink（拐点）和 Notch（断层）模型，通过构建反事实分布来量化个体对税收、补贴、规制等政策的行为反应。

与传统方法不同，`fbunch` 采用**完全数据驱动 (Data-driven)** 的算法来自动选择最优参数，确保了估计结果的稳健性和可复现性。

## 主要功能 (Features)

- **完全数据驱动**：不再依赖肉眼观察，自动选择最优的分箱宽度 (Bin Width)、多项式阶数 (Degree) 和排除窗口 (Excluded Window)。
- **联合判定算法**：采用迭代逻辑，同时确定最优的多项式阶数和窗口范围 (参考 Bosch et al., 2020)。
- **模型支持**：
  - **Kink**：边际激励变化（如累进税率）。
  - **Notch**：平均激励跳跃（如全额征收），支持 **B=M 积分约束** 的全局搜索求解。
- **因果推断**：支持 **结果变量 (Outcome Response)** 分析，估算其他经济变量（如工时、税负、合规度）在断点处的平均因果变化。
- **严谨推断**：支持 **Residual Bootstrap**，可自动计算密度群聚量和结果变量效应的标准误，并提供 Notch 模型的 B=M 假设检验。

## 安装方法 (Installation)

您可以直接通过 Stata 从 GitHub 安装此命令：

```stata
net install fbunch, from("https://raw.githubusercontent.com/fyapeng/fbunch/main")
```

或者，如果您已经下载了文件，请将 `fbunch.ado` 和 `fbunch.sthlp` 放置在您的 Stata 个人 ADO 目录中（通常是 `C:\ado\personal\f\`）。

## 语法 (Syntax)

```stata
fbunch depvar, cutoff(#) [options]
```

### 核心选项说明

| 选项 | 描述 |
| :--- | :--- |
| `cutoff(#)` | **必填**。指定政策断点/阈值的数值。 |
| `width(#)` | 分箱宽度。若不指定，默认基于 Freedman-Diaconis 准则自动计算。 |
| `model(str)` | 模型类型：`kink` (默认) 或 `notch`。 |
| `side(str)` | 群聚方向：`left` (默认，如税收断点) 或 `right` (如补贴门槛)。 |
| `select(str)` | 多项式阶数选择标准：`aic` (默认), `bic`, 或 `cv` (5折交叉验证)。 |
| `constraint` | 仅用于 Notch。强制执行 B=M 积分约束，通过全局搜索寻找最优窗口。 |
| `outcome(var)` | 指定一个结果变量，计算该变量在断点处的因果效应。 |
| `reps(#)` | Bootstrap 重抽样次数 (建议 500)，用于计算标准误。 |

## 使用示例 (Examples)

### 1. 基础 Kink 估计
使用交叉验证 (CV) 自动选择阶数，估计断点为 10,000 处的群聚效应：

```stata
fbunch income, cutoff(10000) width(200) select(cv)
```

### 2. Notch 估计 (带约束)
估计左侧群聚的 Notch 模型，并强制要求满足 "群聚量(B) = 缺失量(M)" 的理论约束：

```stata
fbunch income, cutoff(10000) model(notch) side(left) constraint
```

### 3. 结果变量与因果推断 (全功能)
同时分析收入的群聚分布，以及 **工时 (hours)** 在断点处受到的因果影响，并使用 500 次 Bootstrap 计算标准误：

```stata
fbunch income, cutoff(10000) outcome(hours) reps(500)
```

## 输出结果 (Outputs)

`fbunch` 会自动生成可视化图表：
1.  **密度分布图**：展示实际频数分布与拟合的反事实曲线。
2.  **结果变量图** (若指定 `outcome`)：展示结果变量均值的实际分布与反事实趋势。

并在 Stata 窗口输出详细统计量：
- **Excess Mass (B)**：绝对群聚量。
- **Standard b (B/h0)**：归一化群聚量（用于计算弹性）。
- **Average Impact**：结果变量的平均因果变化。

## 参考文献 (References)

本命令的算法实现基于以下文献：

- **Chetty, R., et al. (2011).** "Adjustment Costs, Firm Responses, and Micro vs. Macro Labor Supply Elasticities." *The Quarterly Journal of Economics*.
- **Kleven, H. J., & Waseem, M. (2013).** "Using Notches to Uncover Optimization Frictions and Structural Elasticities." *The Quarterly Journal of Economics*.
- **Bosch, N., Dekker, V., & Strohmaier, K. (2020).** "A data-driven procedure to determine the bunching window." *International Tax and Public Finance*.

## 作者 (Author)

**Easton Y. Fu**  
Email: easton.y.fu@gmail.com

---
*免责声明：本软件按“原样”提供，不提供任何形式的担保。*
```
