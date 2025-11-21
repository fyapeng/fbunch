*! version 17.0  Date: 2025-11-21
*! Title: fbunch - The Ultimate Bunching Estimator (Consistent Outcome Edition)
*! Update: Relative Impact is now based on Average Y to ensure sign consistency.

capture program drop fbunch
program define fbunch, rclass
    version 14.0
    syntax varname(numeric), Cutoff(real) [ ///
        Width(real 0.0)     /// 自动分箱宽度
        Degree(int 0)       /// 多项式阶数
        Maxdeg(int 7)       /// 最大阶数
        Select(string)      /// 选择标准
        IMprove(real 0.05)  /// 肘部法则
        Window(numlist min=2 max=2) /// 手动窗口
        Model(string)       /// kink 或 notch
        Side(string)        /// left 或 right
        Constraint          /// B=M 约束
        Searchrange(real 0) /// 约束搜索范围
        Outcome(varname)    /// 结果变量
        Reps(int 0)         /// Bootstrap 次数
        Gen(string)         /// 生成变量前缀
        Noplot              /// 禁止画图
        Seed(int 0)         /// 随机种子
        TOLerance(real 0.02) /// 偏差容忍度
    ]

    if "`model'" == "" local model "kink"
    if "`side'" == "" local side "left"
    if "`select'" == "" local select "mse"
    if `seed' != 0 set seed `seed'
    
    tempfile data_collapsed data_main_results base_cf resid_pool bootsave curr_resid
    tempname memhold
    
    * --- 1. 计算总样本数 & 自动分箱 ---
    quietly {
        summarize `varlist', detail
        local total_N = r(N)
        
        if `width' == 0 {
            local iqr = r(p75) - r(p25)
            if `iqr' == 0 | `total_N' == 0 local width = 1
            else local width = round(2 * `iqr' * (`total_N'^(-1/3)), 0.01)
            if `width' <= 0 local width 0.1 
        }
    }
    di _n as txt "Auto-selected bin width: " as res `width'

    * --- 2. 数据预处理 ---
    quietly {
        preserve
        tempvar z bin_id
        gen double `z' = `varlist' - `cutoff'
        gen long `bin_id' = floor(`z' / `width')
        
        if "`outcome'" != "" {
            collapse (count) freq=`z' (mean) out_mean=`outcome', by(`bin_id')
        }
        else {
            collapse (count) freq=`z', by(`bin_id')
            gen out_mean = .
        }
        
        tsset `bin_id'
        tsfill
        replace freq = 0 if freq == .
        gen double bin_center = (`bin_id' * `width') + (`width'/2)
        
        save `data_collapsed', replace
    }

    * --- 3. 运行主估计 ---
    quietly _fbunch_core, cutoff(`cutoff') width(`width') ///
        degree(`degree') maxdeg(`maxdeg') select(`select') improve(`improve') ///
        window(`window') model(`model') side(`side') ///
        `constraint' searchrange(`searchrange') has_outcome("`outcome'") tolerance(`tolerance')
        
    * 提取结果
    local B_main = r(B)
    local b_std_main = r(b_std)
    local b_pct_main = r(b_pct)
    local net_bal_main = r(net_bal)
    
    local diff_Y_avg_main = r(diff_Y_avg)
    local diff_Y_pct_main = r(diff_Y_pct)
    local val_at_cut_main = r(val_at_cut)
    
    local opt_deg = r(deg)
    local win_l = r(w_low)
    local win_r = r(w_high)
    local poly_list "`r(poly_vars)'"
    
    quietly save `data_main_results', replace
    
    * --- 4. Bootstrap ---
    local se_B = .
    local se_b_std = .
    local se_b_pct = .
    local se_net = .
    local p_net = .
    local se_diff_Y_avg = .
    local se_diff_Y_pct = .
    
    if `reps' > 0 {
        di as txt "Running Bootstrap (" as res `reps' as txt " reps)... " _c
        
        quietly {
            use `data_main_results', clear
            local N_total_bins = _N
            
            gen double resid_freq = freq - cf_freq
            gen double resid_out = 0
            gen double cf_out_hat = 0
            if "`outcome'" != "" {
                replace resid_out = out_mean - cf_out
                replace cf_out_hat = cf_out
            }
            
            keep bin_center cf_freq cf_out_hat `poly_list'
            save `base_cf', replace
            
            use `data_main_results', clear
            keep if bin_center < `win_l' | bin_center > `win_r'
            gen double resid_freq = freq - cf_freq
            gen double resid_out = 0
            if "`outcome'" != "" {
                replace resid_out = out_mean - cf_out
            }
            keep resid_freq resid_out
            
            count
            if r(N) < 5 {
                noisily di as error _n "Warning: Window too large. SEs skipped."
                local do_boot = 0
            }
            else {
                local do_boot = 1
                save `resid_pool', replace
            }
        }
        
        if `do_boot' {
            postfile `memhold' double(b_std_boot B_boot b_pct_boot net_boot diff_Y_avg_boot diff_Y_pct_boot) using `bootsave', replace
            
            forvalues i = 1/`reps' {
                quietly {
                    use `resid_pool', clear
                    local exp_f = ceil(`N_total_bins' / _N)
                    if `exp_f' > 1 expand `exp_f'
                    gen double rand_sort = runiform()
                    sort rand_sort
                    keep in 1/`N_total_bins'
                    gen long _id = _n
                    save `curr_resid', replace
                    
                    use `base_cf', clear
                    gen long _id = _n
                    merge 1:1 _id using `curr_resid', nogenerate
                    
                    gen double freq_star = cf_freq + resid_freq
                    replace freq_star = 0 if freq_star < 0
                    gen double out_star = .
                    if "`outcome'" != "" {
                        replace out_star = cf_out_hat + resid_out
                    }
                    
                    reg freq_star `poly_list' if bin_center < `win_l' | bin_center > `win_r'
                    predict double cf_star, xb
                    
                    local c_l = cond("`side'"=="left", `win_l', 0)
                    local c_r = cond("`side'"=="left", 0, `win_r')
                    
                    gen double exc_star = freq_star - cf_star
                    sum exc_star if bin_center >= `c_l' & bin_center <= `c_r', meanonly
                    local B_star = r(sum)
                    
                    sum cf_star if abs(bin_center) < `width', meanonly
                    local h0_star = r(mean)
                    if `h0_star' <= 0 local h0_star = 1e-6
                    local b_std_star = `B_star' / `h0_star'
                    
                    sum cf_star if bin_center >= `c_l' & bin_center <= `c_r', meanonly
                    local C_tot_star = r(sum)
                    if `C_tot_star' <= 0 local C_tot_star = 1e-6
                    local b_pct_star = (`B_star' / `C_tot_star') * 100
                    
                    gen double diff_all_star = freq_star - cf_star
                    sum diff_all_star if bin_center >= `win_l' & bin_center <= `win_r', meanonly
                    local net_star = r(sum)
                    
                    local diff_Y_avg_star = .
                    local diff_Y_pct_star = .
                    
                    if "`outcome'" != "" {
                        reg out_star `poly_list' if bin_center < `win_l' | bin_center > `win_r'
                        predict double cf_out_star, xb
                        
                        gen double Y_mass_obs = freq_star * out_star
                        gen double Y_mass_cf  = cf_star * cf_out_star
                        
                        sum Y_mass_obs if bin_center >= `win_l' & bin_center <= `win_r', meanonly
                        local sum_Y_obs = r(sum)
                        sum Y_mass_cf if bin_center >= `win_l' & bin_center <= `win_r', meanonly
                        local sum_Y_cf = r(sum)
                        
                        sum freq_star if bin_center >= `win_l' & bin_center <= `win_r', meanonly
                        local sum_N_obs = r(sum)
                        if `sum_N_obs' <= 0 local sum_N_obs = 1e-6
                        
                        sum cf_star if bin_center >= `win_l' & bin_center <= `win_r', meanonly
                        local sum_N_cf = r(sum)
                        if `sum_N_cf' <= 0 local sum_N_cf = 1e-6
                        
                        local avg_obs = `sum_Y_obs' / `sum_N_obs'
                        local avg_cf  = `sum_Y_cf' / `sum_N_cf'
                        
                        local diff_Y_avg_star = `avg_obs' - `avg_cf'
                        local diff_Y_pct_star = ((`avg_obs' - `avg_cf') / `avg_cf') * 100
                    }
                    
                    post `memhold' (`b_std_star') (`B_star') (`b_pct_star') (`net_star') (`diff_Y_avg_star') (`diff_Y_pct_star')
                }
                if mod(`i', 50) == 0 di "." _c
            }
            postclose `memhold'
            di " Done."
            
            use `bootsave', clear
            quietly {
                sum b_std_boot
                local se_b_std = r(sd)
                sum B_boot
                local se_B = r(sd)
                sum b_pct_boot
                local se_b_pct = r(sd)
                sum net_boot
                local se_net = r(sd)
                if `se_net' == 0 local se_net = 1e-6
                
                if "`outcome'" != "" {
                    sum diff_Y_avg_boot
                    local se_diff_Y_avg = r(sd)
                    sum diff_Y_pct_boot
                    local se_diff_Y_pct = r(sd)
                }
            }
        }
    }
    
    if `se_net' != . {
        local z_stat = `net_bal_main' / `se_net'
        local p_val = 2 * (1 - normal(abs(`z_stat')))
    }
    else {
        local p_val = .
    }

    quietly use `data_main_results', clear

    * --- 5. 结果输出 ---
    di _n as txt "{hline 72}"
    di as txt "FBunch Results: "
    di as txt "Model: " as res upper("`model'") " (" upper("`side'") ")" _col(45) as txt "Total Obs: " as res %12.0f `total_N'
    di as txt "{hline 72}"
    di as txt "Parameters:"
    di as txt "  Bin Width       : " as res %9.2f `width' _col(45) as txt "Poly Deg   : " as res `opt_deg' " (`select')"
    di as txt "  Excluded Window : [" as res %9.1f `win_l' ", " %9.1f `win_r' "]" 
    if "`constraint'" != "" di as txt "  Constraint      : " as res "On (B=M)"
    di as txt "{hline 72}"
    di as txt "Density Estimates:"
    di as txt "  Excess Mass (B)   : " as res %9.0f `B_main' _col(45) as txt "(SE: " as res %9.1f `se_B' as txt ")"
    di as txt "  Standard b (B/h0) : " as res %9.3f `b_std_main' _col(45) as txt "(SE: " as res %9.3f `se_b_std' as txt ")"
    di as txt "  Relative b (B/Sum): " as res %9.2f `b_pct_main' "%" _col(45) as txt "(SE: " as res %9.2f `se_b_pct' "%" as txt ")"
    
    if "`model'" == "notch" {
        di as txt "  Net Balance (B-M) : " as res %9.0f `net_bal_main' _col(45) as txt "(SE: " as res %9.1f `se_net' as txt ")"
        di as txt "  H0: B=M (p-value) : " as res %9.3f `p_val' _col(45) as txt cond(`p_val'<0.05, "* Reject H0 *", "(Not Reject H0)")
    }
    
    if "`outcome'" != "" {
        di as txt "{hline 72}"
        di as txt "Outcome Analysis (`outcome') in Window:"
        di as txt "  Avg Change (Y)    : " as res %9.3f `diff_Y_avg_main' _col(45) as txt "(SE: " as res %9.3f `se_diff_Y_avg' as txt ")"
        di as txt "  Relative Impact   : " as res %9.2f `diff_Y_pct_main' "%" _col(45) as txt "(SE: " as res %9.2f `se_diff_Y_pct' "%" as txt ")"
    }
    di as txt "{hline 72}"

    return scalar b_std = `b_std_main'
    return scalar B = `B_main'
    return scalar se_b = `se_b_std'
    return scalar se_B = `se_B'
    if "`outcome'" != "" {
        return scalar diff_Y_avg = `diff_Y_avg_main'
        return scalar diff_Y_pct = `diff_Y_pct_main'
        return scalar se_diff_Y_avg = `se_diff_Y_avg'
    }
    
    if "`noplot'" == "" {
        _fbunch_plot, width(`width') cutoff(`cutoff') model(`model') side(`side') ///
            b_val(`b_std_main') win_l(`win_l') win_r(`win_r') has_outcome("`outcome'")
    }
    if "`gen'" != "" {
        capture drop `gen'_*
        rename bin_center `gen'_bin
        rename freq `gen'_freq
        capture rename out_mean `gen'_outcome
        save `gen'_results.dta, replace
        di as txt "Data saved to `gen'_results.dta"
    }
    restore
end

* ==============================================================================
* 子程序：核心算法 (Core)
* ==============================================================================
capture program drop _fbunch_core
program define _fbunch_core, rclass
    syntax, Cutoff(real) Width(real) [Degree(int 0) Maxdeg(int 7) Select(string) Improve(real 0.05) Window(string) Model(string) Side(string) Constraint Searchrange(real 0) has_outcome(string) Tolerance(real 0.02)]

    forvalues p = 1/`maxdeg' {
        capture drop z_pow_`p'
        gen double z_pow_`p' = bin_center^`p'
    }
    
    * 1. 确定搜索起始状态
    local z_lower = -`width'
    local z_upper = `width'
    local fixed_window = 0
    if "`window'" != "" {
        tokenize `window'
        local z_lower = `1'
        local z_upper = `2'
        local fixed_window = 1
    }
    
    local current_degree = cond(`degree'>0, `degree', 1)
    local conv = 0
    local iter = 0
    sum bin_center, meanonly
    local min_z = r(min)
    local max_z = r(max)

    if `fixed_window' {
        local conv = 1
        if `degree' == 0 {
             _fbunch_select_deg, lower(`z_lower') upper(`z_upper') max(`maxdeg') sel(`select') imp(`improve')
             local current_degree = r(deg)
        }
    }
    
    * 2. 联合迭代循环
    while `conv' == 0 {
        local iter = `iter' + 1
        
        if `degree' == 0 {
             _fbunch_select_deg, lower(`z_lower') upper(`z_upper') max(`maxdeg') sel(`select') imp(`improve')
             local current_degree = r(deg)
        }
        
        local reg_vars ""
        forvalues k=1/`current_degree' {
            local reg_vars "`reg_vars' z_pow_`k'"
        }
        quietly reg freq `reg_vars' if bin_center < `z_lower' | bin_center > `z_upper'
        
        capture drop fh fse
        predict double fh, xb
        predict double fse, stdf
        
        local chk_l = `z_lower' - 1.5*`width'
        local chk_r = `z_upper' + 1.5*`width'
        local expl = 0
        local expr = 0
        
        sum freq if abs(bin_center - `chk_l') <= 1.5*`width'+0.01, meanonly
        local vl = r(mean)
        sum fh if abs(bin_center - `chk_l') <= 1.5*`width'+0.01, meanonly
        local pl = r(mean)
        sum fse if abs(bin_center - `chk_l') <= 1.5*`width'+0.01, meanonly
        local sl = r(mean)
        
        local dev_l = abs(`vl'-`pl')/abs(`pl')
        if abs(`vl'-`pl') > 1.96*`sl' & `dev_l' > `tolerance' & `vl'!=. {
            if "`model'"=="kink" & `vl'>`pl' local expl=1
            if "`model'"=="notch" {
                if "`side'"=="left" & `vl'>`pl' local expl=1
                if "`side'"=="right" & `vl'<`pl' local expl=1
            }
        }
        
        sum freq if abs(bin_center - `chk_r') <= 1.5*`width'+0.01, meanonly
        local vr = r(mean)
        sum fh if abs(bin_center - `chk_r') <= 1.5*`width'+0.01, meanonly
        local pr = r(mean)
        sum fse if abs(bin_center - `chk_r') <= 1.5*`width'+0.01, meanonly
        local sr = r(mean)
        
        local dev_r = abs(`vr'-`pr')/abs(`pr')
        if abs(`vr'-`pr') > 1.96*`sr' & `dev_r' > `tolerance' & `vr'!=. {
            if "`model'"=="kink" & `vr'>`pr' local expr=1
            if "`model'"=="notch" {
                if "`side'"=="left" & `vr'<`pr' local expr=1
                if "`side'"=="right" & `vr'>`pr' local expr=1
            }
        }
        
        if `expl' local z_lower = `z_lower' - `width'
        if `expr' local z_upper = `z_upper' + `width'
        if !`expl' & !`expr' local conv = 1
        if (`z_upper' - `z_lower') > (`max_z' - `min_z') / 2 local conv 1
        if `iter' > 100 local conv 1
    }
    
    local final_vars ""
    forvalues k=1/`current_degree' {
        local final_vars "`final_vars' z_pow_`k'"
    }

    * --- 约束搜索 ---
    if "`model'"=="notch" & "`constraint'"!="" {
        local min_bal = 1e30
        local best_bd = .
        local s_end = cond(`searchrange'>0, `searchrange', 50*`width')
        if "`side'"=="left" {
            local start = `width'
            local end = `z_upper' + `s_end'
            forvalues c = `start'(`width')`end' {
                quietly reg freq `final_vars' if bin_center < `z_lower' | bin_center > `c'
                if e(N) > `current_degree'+5 {
                    capture drop fh
                    predict double fh, xb
                    gen double diff = freq - fh
                    sum diff if bin_center >= `z_lower' & bin_center <= `c', meanonly
                    if abs(r(sum)) < `min_bal' {
                        local min_bal = abs(r(sum))
                        local best_bd = `c'
                    }
                    drop diff
                }
            }
            local z_upper = `best_bd'
        }
        else {
            local start = -`width'
            local end = `z_lower' - `s_end'
            forvalues c = `start'(-`width')`end' {
                quietly reg freq `final_vars' if bin_center < `c' | bin_center > `z_upper'
                if e(N) > `current_degree'+5 {
                    capture drop fh
                    predict double fh, xb
                    gen double diff = freq - fh
                    sum diff if bin_center >= `c' & bin_center <= `z_upper', meanonly
                    if abs(r(sum)) < `min_bal' {
                        local min_bal = abs(r(sum))
                        local best_bd = `c'
                    }
                    drop diff
                }
            }
            local z_lower = `best_bd'
        }
    }
    
    * --- 3. 最终计算 ---
    reg freq `final_vars' if bin_center < `z_lower' | bin_center > `z_upper'
    capture drop cf_freq
    predict double cf_freq, xb
    
    local c_l = cond("`side'"=="left", `z_lower', 0)
    local c_r = cond("`side'"=="left", 0, `z_upper')
    
    gen double exc = freq - cf_freq
    sum exc if bin_center >= `c_l' & bin_center <= `c_r', meanonly
    local B = r(sum)
    sum cf_freq if abs(bin_center) < `width', meanonly
    local h0 = r(mean)
    if `h0'<=0 local h0 = 1e-6
    sum cf_freq if bin_center >= `c_l' & bin_center <= `c_r', meanonly
    local C_tot = r(sum)
    if `C_tot'<=0 local C_tot = 1e-6
    gen double diff_all = freq - cf_freq
    sum diff_all if bin_center >= `z_lower' & bin_center <= `z_upper', meanonly
    local net = r(sum)
    
    local diff_Y_avg = .
    local diff_Y_pct = .
    local val_at_cut = .
    if "`has_outcome'" != "" {
        reg out_mean `final_vars' if bin_center < `z_lower' | bin_center > `z_upper'
        capture drop cf_out
        predict double cf_out, xb
        
        gen double Y_mass_obs = freq * out_mean
        gen double Y_mass_cf  = cf_freq * cf_out
        
        sum Y_mass_obs if bin_center >= `z_lower' & bin_center <= `z_upper', meanonly
        local sum_Y_obs = r(sum)
        sum Y_mass_cf if bin_center >= `z_lower' & bin_center <= `z_upper', meanonly
        local sum_Y_cf = r(sum)
        
        sum freq if bin_center >= `z_lower' & bin_center <= `z_upper', meanonly
        local sum_N_obs = r(sum)
        if `sum_N_obs' <= 0 local sum_N_obs = 1e-6
        
        sum cf_freq if bin_center >= `z_lower' & bin_center <= `z_upper', meanonly
        local sum_N_cf = r(sum)
        if `sum_N_cf' <= 0 local sum_N_cf = 1e-6
        
        * 核心修复：改用平均值计算相对影响
        local avg_obs = `sum_Y_obs' / `sum_N_obs'
        local avg_cf  = `sum_Y_cf' / `sum_N_cf'
        
        local diff_Y_avg = `avg_obs' - `avg_cf'
        local diff_Y_pct = ((`avg_obs' - `avg_cf') / `avg_cf') * 100
        
        sum out_mean if abs(bin_center) < `width', meanonly
        local val_at_cut = r(mean)
    }

    return scalar B = `B'
    return scalar b_std = `B' / `h0'
    return scalar b_pct = (`B' / `C_tot') * 100
    return scalar deg = `current_degree'
    return scalar w_low = `z_lower'
    return scalar w_high = `z_upper'
    return scalar net_bal = `net'
    return local poly_vars "`final_vars'"
    return scalar diff_Y_avg = `diff_Y_avg'
    return scalar diff_Y_pct = `diff_Y_pct'
    return scalar val_at_cut = `val_at_cut'
end

capture program drop _fbunch_select_deg
program define _fbunch_select_deg, rclass
    syntax, lower(real) upper(real) max(int) sel(string) imp(real)
    
    * CV 始终通过划分5折来实现
    tempvar cv_grp
    gen `cv_grp' = ceil(runiform()*5) if bin_center < `lower' | bin_center > `upper'
    
    local best_deg = 1
    local prev_crit = .
    
    forvalues p = 1/`max' {
        local vars ""
        forvalues k=1/`p' {
            local vars "`vars' z_pow_`k'"
        }
        
        * 计算 CV 预测误差 (PRESS)
        local press = 0
        forvalues k=1/5 {
            quietly reg freq `vars' if `cv_grp'!=. & `cv_grp'!=`k'
            tempvar p_cv
            quietly predict double `p_cv' if `cv_grp'==`k'
            quietly replace `p_cv' = (`p_cv' - freq)^2
            quietly sum `p_cv', meanonly
            local press = `press' + r(sum)
            drop `p_cv'
        }
        
        quietly count if bin_center < `lower' | bin_center > `upper'
        local N_eff = r(N)
        local k_param = `p' + 1
        
        local crit = .
        if "`sel'" == "mse" local crit = `press'
        if "`sel'" == "aic" local crit = `N_eff' * ln(`press'/`N_eff') + 2 * `k_param'
        if "`sel'" == "bic" local crit = `N_eff' * ln(`press'/`N_eff') + `k_param' * ln(`N_eff')
        
        if `p' > 1 {
            local pct = (`prev_crit' - `crit') / abs(`prev_crit')
            if `pct' > `imp' local best_deg = `p'
        }
        local prev_crit = `crit'
    }
    return scalar deg = `best_deg'
end

capture program drop _fbunch_plot
program define _fbunch_plot
    syntax, Width(real) Cutoff(real) Model(string) Side(string) b_val(real) win_l(real) win_r(real) [has_outcome(string)]
    local tstr = "Density: b=" + string(`b_val', "%9.3f")
    twoway (bar freq bin_center, color(navy%50) barwidth(`width')) ///
           (line cf_freq bin_center, color(maroon) lwidth(thick)), ///
           xline(`win_l' `win_r', lcolor(green) lpattern(dash)) ///
           xline(0, lcolor(black) lwidth(thin)) ///
           legend(off) name(g_dens, replace) nodraw
    if "`has_outcome'" != "" {
        twoway (scatter out_mean bin_center, ms(Oh) mc(navy%60)) ///
               (line cf_out bin_center, color(maroon) lwidth(thick)), ///
               xline(`win_l' `win_r', lcolor(green) lpattern(dash)) ///
               xline(0, lcolor(black) lwidth(thin)) ///
               legend(off) name(g_out, replace) nodraw
        graph combine g_dens g_out, col(1) ysize(8) xsize(6) imargin(small)
    }
    else {
        graph display g_dens, ysize(5) xsize(6)
    }
end
