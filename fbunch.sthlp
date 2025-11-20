{smcl}
{* *! version 15.0  21Nov2025}{...}
{vieweralsosee "reghdfe" "help reghdfe"}{...}
{vieweralsosee "rdrobust" "help rdrobust"}{...}
{viewerjumpto "语法 Syntax" "fbunch##syntax"}{...}
{viewerjumpto "描述 Description" "fbunch##description"}{...}
{viewerjumpto "选项 Options" "fbunch##options"}{...}
{viewerjumpto "算法原理 Methods" "fbunch##methods"}{...}
{viewerjumpto "示例 Examples" "fbunch##examples"}{...}
{viewerjumpto "参考文献 References" "fbunch##references"}{...}
{viewerjumpto "作者 Author" "fbunch##author"}{...}
{title:标题}

{p2colset 5 18 20 2}{...}
{p2col :{bf:fbunch} {hline 2}}基于数据驱动的群聚分析估计量 (Data-driven Bunching Estimator){p_end}
{p2colreset}{...}


{marker syntax}{...}
{title:语法 Syntax}

{p 8 17 2}
{cmd:fbunch}
{it:depvar}
{cmd:,}
{opt c:utoff(#)}
[{it:options}]

{synoptset 22 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:基础模型}
{synopt :{opt c:utoff(#)}}指定政策发生变化的断点/阈值 (必填){p_end}
{synopt :{opt w:idth(#)}}指定分箱宽度 (默认基于 Freedman-Diaconis 准则自动计算){p_end}
{synopt :{opt m:odel(string)}}模型类型: {bf:kink} (默认) 或 {bf:notch}{p_end}
{synopt :{opt s:ide(string)}}群聚方向: {bf:left} (默认) 或 {bf:right}{p_end}

{syntab:参数自动选择}
{synopt :{opt d:egree(#)}}多项式阶数 (0=自动选择){p_end}
{synopt :{opt maxdeg(#)}}自动选择时的最大阶数 (默认 7){p_end}
{synopt :{opt sel:ect(string)}}阶数选择标准: {bf:aic}, {bf:bic}, {bf:cv} (交叉验证){p_end}
{synopt :{opt imp:rove(#)}}阶数选择的"肘部法则"阈值 (默认 0.05，即提升需>5%){p_end}
{synopt :{opt win:dow(numlist)}}手动指定排除窗口，例如 {opt window(-500 500)}{p_end}
{synopt :{opt tol:erance(#)}}窗口搜索的相对偏差容忍度 (默认 0.02){p_end}

{syntab:Notch 约束}
{synopt :{opt cons:traint}}强制执行 B=M 积分约束 (仅限 Notch 模型){p_end}
{synopt :{opt search:range(#)}}B=M 约束时的最大搜索范围 (默认为自动){p_end}

{syntab:因果推断}
{synopt :{opt out:come(varname)}}指定结果变量，计算该变量在断点处的因果效应{p_end}
{synopt :{opt r:eps(#)}}Bootstrap 重抽样次数 (推荐 500)，用于计算标准误{p_end}
{synopt :{opt seed(#)}}设置随机数种子以复现 Bootstrap 结果{p_end}

{syntab:输出与绘图}
{synopt :{opt g:en(prefix)}}保存生成的反事实数据 (bin, freq, cf_freq 等){p_end}
{synopt :{opt nop:lot}}禁止输出图形{p_end}
{synoptline}
{p2colreset}{...}


{marker description}{...}
{title:描述 Description}

{pstd}
{cmd:fbunch} 是一个用于估计政策断点处群聚效应 (Bunching Estimation) 的综合性 Stata 命令。
它通过构建反事实分布 (Counterfactual Distribution) 来量化个体对税收、补贴、规制等断点政策的行为反应。

{pstd}
该命令的核心优势在于{bf:完全数据驱动 (Data-driven)}：它不依赖研究者的视觉判断来确定排除窗口和多项式阶数，
而是采用迭代算法自动寻找统计上最优的参数组合，从而提高了研究的可复现性。

{pstd}
此外，它支持{bf:结果变量分析 (Outcome Response)}，能够估算其他经济变量（如工时、税负、合规度）在断点处的平均因果变化。


{marker methods}{...}
{title:算法原理 Methods and Formulas}

{pstd}
{bf:1. 窗口与阶数的联合判定 (Joint Determination)}

{pstd}
传统的群聚分析通常依赖目测来确定排除窗口 (Visual Inspection, Saez 2010)。
{cmd:fbunch} 采用了基于 {bf:Bosch et al. (2020)} 的数据驱动算法，并进行了改进：

{pstd}
{ul:A. 窗口搜索 (Window Selection)}:
程序从断点处开始向外迭代，检验观测频数与反事实拟合值之间的差异是否具有统计显著性。
判据基于预测标准误 (Forecast Standard Error, stdf)。
为了防止大样本下的过度扩张，程序引入了{bf:定向逻辑 (Directional Logic)}和{bf:容忍度 (Tolerance)}：
仅当 Kink 出现凸起，或 Notch 出现理论预期的凸起/空洞，且相对偏差超过 {opt tolerance} 时，窗口才继续扩张。

{pstd}
{ul:B. 阶数选择 (Degree Selection)}:
在每一个候选窗口下，程序都会重新评估最优多项式阶数。
为了防止高阶过拟合 (Overfitting)，程序引入了{bf:肘部法则 (Elbow Rule)}：
仅当高一阶模型使 AIC/BIC/MSE 的降低幅度超过 {opt improve} (默认 5%) 时，才选择更高的阶数。

{pstd}
{bf:2. Notch 模型的积分约束 (Integration Constraint)}

{pstd}
对于 Notch 模型，理论要求群聚增加的人数 (B) 等于空洞减少的人数 (M)。
若指定 {opt constraint}，程序将在统计确定的窗口基础上，进行全局网格搜索，
寻找使 Net Balance (B-M) 最小化的窗口边界 (Kleven & Waseem, 2013)。

{pstd}
{bf:3. 统计量计算}

{pstd}
{bf:标准化群聚量 (Standard b)} (Chetty et al., 2011):
{p_end}
{p 8 12 2}b = B / ( h_0(0) ){p_end}
{pstd}表示过剩人群相当于反事实分布在断点处多少个分箱的高度。

{pstd}
{bf:相对群聚量 (Relative b)}:
{p_end}
{p 8 12 2}b_pct = B / ( Sum( C_hat_j ) ) * 100%{p_end}

{pstd}
{bf:4. 结果变量因果效应 (Outcome Response)}

{pstd}
当指定 {opt outcome(y)} 时，程序计算平均结果变量的反事实分布 y_hat_j。
{p_end}
{pstd}
{bf:平均效应 (Average Change)}: 窗口内个体 Y 值的平均变化量 (LATE)。
{p_end}
{p 8 12 2}Delta_Y_avg = E[Y|Window, Obs] - E[Y|Window, Counterfactual]{p_end}

{pstd}
{bf:5. 标准误}

{pstd}
使用残差自助法 (Residual Bootstrap)。对非窗口区域的残差进行有放回重抽样，生成新的伪样本分布，并重新估计。


{marker examples}{...}
{title:示例 Examples}

{pstd}
为了演示命令功能，我们生成一份包含 Kink 和 Notch 特征的模拟数据。
您可以点击下方蓝色的命令直接运行：
{p_end}

    {hline}
    {stata "clear all":. clear all}
    {stata "set seed 2025":. set seed 2025}
    {stata "set obs 100000":. set obs 100000}
    
    {it:* 1. 生成潜变量 (Z=收入, Y=纳税依从度)}
    {stata "gen z_star = exp(rnormal(9.3, 0.5))":. gen z_star = exp(rnormal(9.3, 0.5))}
    {stata "gen y_star = 100 + 0.05 * z_star + rnormal(0, 50)":. gen y_star = 100 + 0.05 * z_star + rnormal(0, 50)}

    {it:* 2. 生成 Kink 数据 (Cutoff=10000)}
    {stata "gen z_kink = z_star":. gen z_kink = z_star}
    {stata "gen y_kink = y_star":. gen y_kink = y_star}
    {stata "replace z_kink = 10000 + (z_star - 10000)*0.6 if z_star > 10000":. replace z_kink = 10000 + (z_star - 10000)*0.6 if z_star > 10000}
    {stata "replace z_kink = z_kink + rnormal(0, 100)":. replace z_kink = z_kink + rnormal(0, 100)}
    {it:* 模拟选择效应：Y值在断点处凸起}
    {stata "replace y_kink = y_kink + 150 if abs(z_kink - 10000) < 300":. replace y_kink = y_kink + 150 if abs(z_kink - 10000) < 300}

    {it:* 3. 生成 Notch 数据 (Cutoff=10000, 左侧群聚)}
    {stata "gen z_notch = z_star":. gen z_notch = z_star}
    {stata "gen y_notch = y_star":. gen y_notch = y_star}
    {stata "replace z_notch = 10000 - runiform(0, 200) if z_star > 10000 & z_star < 11500":. replace z_notch = 10000 - runiform(0, 200) if z_star > 10000 & z_star < 11500}
    {stata "replace z_notch = z_notch + rnormal(0, 100)":. replace z_notch = z_notch + rnormal(0, 100)}
    {it:* 模拟选择效应：留在洞里的人 Y 值偏低}
    {stata "replace y_notch = y_notch - 200 if z_notch > 10000 & z_notch < 11500":. replace y_notch = y_notch - 200 if z_notch > 10000 & z_notch < 11500}
    
    {it:* 4. 数据清洗}
    {stata "keep if z_kink > 0 & z_kink < 25000":. keep if z_kink > 0 & z_kink < 25000}
    {stata "keep if z_notch > 0 & z_notch < 25000":. keep if z_notch > 0 & z_notch < 25000}
    {hline}

{pstd}
{bf:示例 1：基础 Kink 分析 (使用交叉验证选阶数)}
{p_end}
{phang2}{cmd:. fbunch z_kink, cutoff(10000) width(200) select(cv)}{p_end}

{pstd}
{bf:示例 2：包含结果变量分析 (Outcome Analysis)}
{p_end}
{phang2}{cmd:. fbunch z_kink, cutoff(10000) width(200) select(cv) outcome(y_kink)}{p_end}

{pstd}
{bf:示例 3：Notch 分析 (强制 B=M 约束 + Bootstrap 标准误)}
{p_end}
{phang2}{cmd:. fbunch z_notch, cutoff(10000) model(notch) select(cv) constraint outcome(y_notch) reps(100)}{p_end}


{marker references}{...}
{title:参考文献 References}

{phang}
Bosch, N., Dekker, V., & Strohmaier, K. (2020). A data-driven procedure to determine the bunching window: An application to the Netherlands. {it:International Tax and Public Finance}, 27, 951–979.

{phang}
Chetty, R., Friedman, J. N., Olsen, T., & Pistaferri, L. (2011). Adjustment Costs, Firm Responses, and Micro vs. Macro Labor Supply Elasticities: Evidence from Danish Tax Records. {it:The Quarterly Journal of Economics}, 126(2), 749–804.

{phang}
Kleven, H. J. (2016). Bunching. {it:Annual Review of Economics}, 8(1), 435–464.

{phang}
Kleven, H. J., & Waseem, M. (2013). Using Notches to Uncover Optimization Frictions and Structural Elasticities: Theory and Evidence from Pakistan. {it:The Quarterly Journal of Economics}, 128(2), 669–723.

{phang}
Saez, E. (2010). Do Taxpayers Bunch at Kink Points? {it:American Economic Journal: Economic Policy}, 2(3), 180–212.


{marker author}{...}
{title:作者 Author}

{pstd}Easton Y. Fu{p_end}
{pstd}Email: easton.y.fu@gmail.com{p_end}