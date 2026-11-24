# Walker 星座参数与项目规则

本文以原项目 `D:\Program Files\MATLAB\project\Satellite_Routing\Satellite_Routing` 的源码为准，记录仿真配置，不把它们当作各运营商当前实际在轨星座的数据。

## 1. 代码中的 Walker 构型

| 符号 | 原代码变量 | 含义 |
|---|---|---|
| `P` | `M` | 轨道面数 |
| `S` | `N` | 每轨卫星数 |
| `T=P×S` | `M*N` | 总卫星数 |
| `h` | `H_km` | 轨道高度，km |
| `i` | `inclination_deg` | 轨道倾角，度 |
| `W` | `orbit_range_deg` | RAAN 展开范围，度 |
| `F` | `F` | 相邻轨道面的相位因子，由主脚本赋值 |
| 最低仰角 | `satellite_angle` | 地面覆盖参数；纯星间路径无需使用 |

本项目以 `W=180°` 表示 Walker-Star 类，以 `W=360°` 表示 Walker-Delta 类。Walker 记号可写作 `i:T/P/F`。代码中圆轨道偏心率 `e=0`、地球半径 `Radius_Earth_km=6371` km、轨道半径 `Radius_Orbit_km=6371+H_km`。

轨道面及卫星初始相位由下式生成，其中 `m=1,…,M`，`n=1,…,N`：

```text
RAAN Ω_m = (m−1) × W/M
平近点角 M_(m,n) = (n−1) × 360°/N + (m−1) × F × 360°/(M×N)
```

对应 `Main_routing_RandomPath.m` 第 170–178 行。相邻轨道面的 RAAN 差是 `W/M`；同轨相邻卫星的初始相位差是 `360°/N`。

## 2. 星座参数：以 `Main_routing_RandomPath.m` 为第一版基准

| 模型 | 项目构型 | `M` | `N` | 总数 | 高度 km | 倾角 | RAAN 范围 | RAAN 步长 | 最低仰角 |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|
| `DesignPolar` | Star | 10 | 30 | 300 | 550 | 86° | 180° | 18° | 25° |
| `Iridium` | Star | 6 | 11 | 66 | 780 | 86° | 180° | 30° | 8.2° |
| `OneWeb` | Star | 18 | 40 | 720 | 1200 | 88° | 180° | 10° | 20° |
| `Design` | Delta | 10 | 30 | 300 | 550 | 60° | 360° | 36° | 25° |
| `Defined` | Delta | `Defined` | `Defined` | `Defined²` | 550 | 53° | 360° | `360/Defined`° | 20° |
| `Starlink` | Delta | 72 | 22 | 1584 | 550 | 53° | 360° | 5° | 25° |
| `Kuiper` | Delta | 34 | 34 | 1156 | 600 | 42° | 360° | 约 10.588° | 30° |

来源：`Main_routing_RandomPath.m` 第 58–120 行。此脚本第 60 行设 `Starlink`，第 66 行再次设 `Design`，故按原样运行时实际选用 `Design`。此脚本的 `Defined=15` 被注释，直接切换到 `Defined` 会遇到未定义变量；`Main_Rnd_Location.m` 第 64 行另有 `Defined=15` 的实验设置。

## 3. 不同主脚本之间的参数冲突

原项目没有统一参数文件，不能把不同主脚本中的数字混为同一模型。

| 参数 | `Main_routing_RandomPath.m` | `Main_PPT.m` | 说明 |
|---|---:|---:|---|
| `DesignPolar` 每轨卫星数 | 30 | 20 | 两套不同的自定义 Star 模型。 |
| `Kuiper` 高度 | 600 km | 630 km | 应成组选用。 |
| `Kuiper` 倾角 | 42° | 51.9° | 应成组选用。 |
| `Kuiper` 最低仰角 | 30° | 20° | 只影响地面覆盖。 |
| `F` | 0 | 6 | 相位因子由脚本设定，不属于星座名称本身。 |

`Main_Rnd_Location.m` 另设 `F=1`，并在 `Kuiper` 分支写了最低仰角 `2°`，与其旁“1075 km”注释不一致。后续应采用代码值并标注来源，不凭注释改值。

`Main_PPT.m` 中除上述差异外，`Design`、`Starlink`、`Iridium`、`OneWeb` 的表列几何参数与第一版基准一致。来源：`Main_PPT.m` 第 38–89、138–146 行；`Main_Rnd_Location.m` 第 59–101、146–153 行。

## 4. 原项目实际使用的 ISL 拓扑和权重

`fun_SatelliteNeighbors.m` 为 `(m,n)` 给出四个候选邻居：同轨 `(m,n±1)`，跨轨 `(m±1,n)`，编号到边界时循环。`fun_Graph.m` 实际逐个加入同轨 `(m,n)↔(m,n+1)` 和跨轨 `(m,n)↔(m+1,n)` 双向边；遍历全部节点后形成前后方向的邻居。

- Delta (`orbit_range_deg=360`)：保留末轨道面 `M` 与首轨道面 `1` 的环绕跨轨边。
- Star (`orbit_range_deg=180`)：当 `m==M` 时跳过该跨轨边，因此首末轨道面之间形成接缝；同轨卫星仍首尾连接。
- 跨轨配对固定为相邻轨道面的**相同编号 `n`**。原项目没有动态选最近卫星，也没有显式检查地球遮挡、ISL 可见性或最大允许链路长度。
- 卫星节点一维编号为 `Index2to1(m,n)=(m−1)*N+n`。
- ISL 原始长度由卫星三维坐标的欧氏距离得到，单位 km。`fun_Graph.m` 随后用 `Graph_Matrix*1000/c*1000` 把长度转换为传播时延，单位 ms。所以最终 `Graph_Matrix` 不是 km。

来源：`fun_SatelliteNeighbors.m`、`fun_Graph.m`、`fun_Distance.m`。

## 5. 后续星内最短路实验应遵循的约定

1. 使用 `Main_routing_RandomPath.m` 上表参数和该脚本的 `F=0` 作为第一版统一基准；复现其他主脚本时单独建立配置，记录来源及 `F`。
2. 纯 satellite-to-satellite 路径只使用卫星节点和 `fun_Graph.m` 的拓扑；不加入 `fun_GraphwithGS.m` 的两个地面节点。
3. Hop-minimizing path：每条允许的 ISL 权重为 1。Distance-minimizing path：每条允许的 ISL 权重为该时刻三维长度，单位 km。若全部链路传播速度均为 `c`，最短距离路径与最短传播时延路径相同（并列解除外）。
4. 对同轨均匀圆轨道卫星，轨内相邻 ISL 的理想弦长是 `2*(6371+H_km)*sin(pi/N)`，因此同一配置下等长。轨间 ISL 要按相邻轨道面同编号卫星的实际三维坐标计算；它随相位和卫星所在位置变化。`F≠0` 时不能直接套用“同纬度卫星”的简式。
5. `Main_routing_RandomPath.m` 使用 `slot=2 s`、`Duration=2 s`，仅一个时间采样点。若后续做动态仿真，要延长时长并检查 `fun_SatelliteTrajectory.m` 中 `mu`（m³/s²）与 `Radius_Orbit_km`（km）混用的单位问题。

