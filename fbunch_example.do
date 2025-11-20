* ==============================================================================
* fbunch_example.do
* Demonstration script for the fbunch command
* Author: Easton Y. Fu
* ==============================================================================

clear all
set more off
set seed 2025        // 设置随机种子以保证结果可复现
set obs 200000       // 生成 20 万个观测值
set scheme s1color   // 设置绘图风格

* 定义政策断点
scalar cutoff = 10000

* ------------------------------------------------------------------------------
* 辅助程序：生成平滑的基础结果变量 Y
* ------------------------------------------------------------------------------
capture program drop gen_smooth_y
program define gen_smooth_y
    args z_var y_name
    * Y 与 Z 正相关，包含随机噪音
    gen `y_name' = 100 + 0.05 * `z_var' + rnormal(0, 50)
end

* ==============================================================================
* 场景 1: Kink (拐点)
* ------------------------------------------------------------------------------
* 故事背景：累进税率导致高收入者向断点处聚集。
* 预期图形：密度在断点处凸起；结果变量(Y)在断点处也表现出正向偏离。
* ==============================================================================
di _n ">>> Generating Kink Data..."
gen z_star = exp(rnormal(9.3, 0.5)) // 潜在收入分布
gen z_kink = z_star

* 行为反应：断点右侧的人减少劳动供给（向左压缩）
replace z_kink = cutoff + (z_star - cutoff) * 0.6 if z_star > cutoff
replace z_kink = z_kink + rnormal(0, 100) // 加入优化摩擦

* 结果变量 Y (例如：纳税遵从度)
gen_smooth_y z_kink y_kink
* 模拟选择效应：聚集在断点附近的人，Y 值异常偏高
replace y_kink = y_kink + 150 if abs(z_kink - cutoff) < 300

* 清洗数据
keep if z_kink > 0 & z_kink < 25000

* >>> 运行 fbunch 估计 <<<
* 使用 CV (交叉验证) 选择阶数，计算 Outcome 效应
fbunch z_kink, cutoff(10000) width(200) model(kink) side(left) ///
    select(cv) outcome(y_kink) reps(100)

* 保存图片 (用于 GitHub README)
graph export "res_kink.png", replace


* ==============================================================================
* 场景 2: Notch Left (左侧群聚断层)
* ------------------------------------------------------------------------------
* 故事背景：一旦超过 10000 元，全额征收高额税费。
* 预期图形：断点右侧出现"空洞"(Hole)，左侧出现"堆积"(Bunch)。
*          留在空洞里的人通常能力较低，因此 Y 值会出现下陷 (Dip)。
* ==============================================================================
di _n ">>> Generating Notch Left Data..."
clear
set seed 2025
set obs 200000
scalar cutoff = 10000
gen z_star = exp(rnormal(9.3, 0.5))

gen z_notch_L = z_star
local hole_upper = 11500 // 理论上的空洞上界

* 行为反应：位于空洞区间的人逃离到断点左侧
replace z_notch_L = cutoff - runiform(0, 200) if z_star > cutoff & z_star < `hole_upper'
replace z_notch_L = z_notch_L + rnormal(0, 100)

* 结果变量 Y (例如：生产率)
gen_smooth_y z_notch_L y_notch_L
* 模拟选择效应：由于摩擦未能逃离空洞的人，Y 值偏低
replace y_notch_L = y_notch_L - 200 if z_notch_L > cutoff & z_notch_L < `hole_upper'

* 清洗数据
keep if z_notch_L > 0 & z_notch_L < 25000

* >>> 运行 fbunch 估计 <<<
* 开启 constraint (B=M 约束) 和 maxdeg(5) 防止过拟合
fbunch z_notch_L, cutoff(10000)  model(notch) side(left) ///
    select(cv) constraint maxdeg(5) outcome(y_notch_L) reps(100)

* 保存图片
graph export "res_notch_L.png", replace


* ==============================================================================
* 场景 3: Notch Right (右侧群聚断层)
* ------------------------------------------------------------------------------
* 故事背景：只有收入达到 10000 元才能获得大额补贴。
* 预期图形：断点左侧出现"空洞"，右侧出现"堆积"。
*          未能达标（留在空洞里）的人 Y 值偏低。
* ==============================================================================
di _n ">>> Generating Notch Right Data..."
clear
set seed 2025
set obs 200000
scalar cutoff = 10000
gen z_star = exp(rnormal(9.3, 0.5))

gen z_notch_R = z_star
local hole_lower = 8500 // 理论上的空洞下界

* 行为反应：位于空洞区间的人突击增加收入到断点右侧
replace z_notch_R = cutoff + runiform(0, 200) if z_star >= `hole_lower' & z_star < cutoff
replace z_notch_R = z_notch_R + rnormal(0, 100)

* 结果变量 Y (例如：工作能力)
gen_smooth_y z_notch_R y_notch_R
* 模拟选择效应：未能达标的人 Y 值偏低
replace y_notch_R = y_notch_R - 200 if z_notch_R >= `hole_lower' & z_notch_R < cutoff

* 清洗数据
keep if z_notch_R > 0 & z_notch_R < 25000

* >>> 运行 fbunch 估计 <<<
* 右侧群聚模式
fbunch z_notch_R, cutoff(10000) model(notch) side(right) ///
    select(cv) constraint maxdeg(5) outcome(y_notch_R) reps(100)

* 保存图片
graph export "res_notch_R.png", replace

di _n ">>> 所有示例运行完毕。图片已保存。"