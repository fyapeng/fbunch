`fbunch` 是一个用于估计政策断点处群聚效应 (Bunching Estimation) 的综合性 Stata 命令。它支持 Kink（拐点）和 Notch（断层）模型，通过构建反事实分布来量化个体对税收、补贴、规制等政策的行为反应。

与传统依赖“肉眼观察”的方法不同，`fbunch` 采用 **完全数据驱动 (Data-driven)** 与 **联合判定 (Joint Determination)** 算法，自动选择最优参数，确保了估计结果的稳健性、客观性和可复现性。

## 主要功能 (Features)

- **完全数据驱动**：不再依赖主观判断，自动选择最优的分箱宽度 (Bin Width)、多项式阶数 (Degree) 和排除窗口 (Excluded Window)。
- **联合判定算法**：采用严谨的双重迭代逻辑，**同时**确定最优的多项式阶数和窗口范围，解决了阶数与窗口选择的内生性问题。
- **模型支持**：
  - **Kink**：边际激励变化（如累进税率）。
  - **Notch**：平均激励跳跃（如全额征收），支持 **B=M 积分约束** 的全局搜索求解。
- **因果推断**：支持 **结果变量 (Outcome Response)** 分析，估算其他经济变量（如工时、税负、合规度）在断点处的**平均因果变化**。
- **严谨推断**：支持 **Residual Bootstrap**，自动计算密度群聚量和结果变量效应的标准误，并提供 Notch 模型的 B=M 假设检验。

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
| `select(str)` | 多项式阶数选择标准：`mse` (默认), `aic`, 或 `bic`。均基于 5折交叉验证计算。 |
| `improve(#)` | 阶数选择的“肘部法则”阈值 (默认 0.05)，防止高阶过拟合。 |
| `constraint` | 仅用于 Notch。强制执行 B=M 积分约束，通过全局搜索寻找最优窗口。 |
| `outcome(var)` | 指定一个结果变量，计算该变量在断点处的**平均因果效应**。 |
| `reps(#)` | Bootstrap 重抽样次数 (建议 500)，用于计算标准误。 |

## 统计原理 (Methods)

1.  **联合判定算法 (Joint Determination)**：
    程序采用两阶段迭代算法。在每一次尝试扩张窗口时，都会基于当前的非排除样本重新运行模型选择算法（AIC/BIC/CV），确定当前最优的多项式阶数。窗口仅在观测值显著偏离预测值（统计显著 + 经济显著）且符合理论方向（凸起/凹陷）时才继续扩张。

2.  **结果变量分析 (Outcome Response)**：
    为了避免因群聚导致的总人数变化干扰效应判断，本程序报告的是 **平均处理效应 (Average Treatment Effect)**：
    $$ \Delta \bar{Y} = Avg(Y_{obs}) - Avg(Y_{cf}) $$
    相对效应 (Relative Impact) 亦基于平均值计算。

## Stata 示例 (Examples)

以下示例基于 `fbunch_example.do` 生成的模拟数据，展示了三种典型场景。

### 1. Kink 模型 (拐点)
*场景：累进税率导致高收入者向断点处聚集，且结果变量（如纳税遵从度）在断点处凸起。*

```stata
* 使用 AIC 标准，并计算 Outcome 效应
fbunch z_kink, cutoff(10000) width(200) select(aic) improve(0.02) outcome(y_kink) reps(500)
```

**输出结果可视化：**
![Kink Result](images/res_kink.png)

---

### 2. Notch 模型 (左侧群聚)
*场景：税收断层导致断点右侧出现空洞，左侧出现堆积。强制执行 B=M 约束。*

```stata
* 使用 BIC 标准防止过拟合，开启 B=M 约束
fbunch z_notch_L, cutoff(10000) model(notch) select(bic) reps(500) constraint outcome(y_notch_L) improve(0.02)
```

**输出结果可视化：**
![Notch Left Result](images/res_notch_L.png)

---

### 3. Notch 模型 (右侧群聚)
*场景：补贴门槛导致断点左侧出现空洞，右侧出现堆积。*

```stata
* 指定 side(right)，使用 MSE 标准
fbunch z_notch_R, cutoff(10000) model(notch) select(mse) side(right) ///
	constraint outcome(y_notch_R) reps(500)
```

**输出结果可视化：**
![Notch Right Result](images/res_notch_R.png)

## 参考文献 (References)

本命令的算法实现基于以下经典文献及最新方法论：

- **Bosch, N., Dekker, V., & Strohmaier, K. (2020).** "A data-driven procedure to determine the bunching window." *International Tax and Public Finance*.
- **Chetty, R., et al. (2011).** "Adjustment Costs, Firm Responses, and Micro vs. Macro Labor Supply Elasticities." *The Quarterly Journal of Economics*.
- **Kleven, H. J. (2016).** "Bunching." *Annual Review of Economics*
- **Kleven, H. J., & Waseem, M. (2013).** "Using Notches to Uncover Optimization Frictions and Structural Elasticities." *The Quarterly Journal of Economics*.
- **Saez, E. (2010).** "Do Taxpayers Bunch at Kink Points?" *American Economic Journal: Economic Policy*

## 作者 (Author)

**Easton Y. Fu**  
Email: easton.y.fu@gmail.com

---
*Disclaimer: This software is provided "as is", without warranty of any kind.*
```
