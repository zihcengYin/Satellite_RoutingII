function satellites = generate_constellation(cfg)
%GENERATE_CONSTELLATION Generate one circular-orbit Walker constellation snapshot.
%   SATELLITES = GENERATE_CONSTELLATION(CFG) uses the M/N/F, inclination,
%   RAAN span, orbit radius, and snapshot index in CFG. The result is an
%   M-by-N-by-3 array of true ECI Cartesian positions in kilometres.

    requiredModel = {'M', 'N', 'F', 'inclination_deg', 'raan_span_deg'};
    requiredOrbit = {'radius_km', 'eccentricity', ...
        'argument_of_perigee_deg', 'step_deg'};
    if ~isstruct(cfg) || ~isfield(cfg, 'model') || ...
            ~isfield(cfg, 'orbit') || ~isfield(cfg, 'simulation')
        error('cfg must contain model, orbit, and simulation fields.');
    end
    for k = 1:numel(requiredModel)
        if ~isfield(cfg.model, requiredModel{k})
            error('cfg.model.%s is required.', requiredModel{k});
        end
    end
    for k = 1:numel(requiredOrbit)
        if ~isfield(cfg.orbit, requiredOrbit{k})
            error('cfg.orbit.%s is required.', requiredOrbit{k});
        end
    end
    if ~isfield(cfg.simulation, 'time_index') || ...
            ~isfield(cfg.simulation, 'slot_s') || ...
            ~isfield(cfg.simulation, 'duration_s')
        error('cfg.simulation needs time_index, slot_s, and duration_s.');
    end

    M = cfg.model.M;
    N = cfg.model.N;
    if any(~isfinite([M, N, cfg.model.F, cfg.model.inclination_deg, ...
            cfg.model.raan_span_deg, cfg.orbit.radius_km, ...
            cfg.orbit.step_deg])) || M < 2 || N < 2 || ...
            M ~= fix(M) || N ~= fix(N) || cfg.model.F < 0 || ...
            cfg.model.F ~= fix(cfg.model.F) || cfg.orbit.radius_km <= 0
        error('Invalid constellation dimensions or orbit parameters.');
    end
    if cfg.orbit.eccentricity ~= 0
        error('This generator currently supports circular orbits only.');
    end
    timeIndex = cfg.simulation.time_index;
    if ~isscalar(timeIndex) || ~isfinite(timeIndex) || ...
            timeIndex < 1 || timeIndex ~= fix(timeIndex) || ...
            timeIndex > cfg.simulation.duration_s / cfg.simulation.slot_s
        error('time_index must select a snapshot within duration_s.');
    end

    radiusKm = cfg.orbit.radius_km;
    inclination = cfg.model.inclination_deg;
    timeOffsetS = (timeIndex - 1) * cfg.simulation.slot_s; % 第n个采样点对应的时间
    angularAdvanceDeg = (timeIndex - 1) * cfg.orbit.step_deg;

    position = zeros(M, N, 3); % 3D coordinate of sitellite(m,n) 
    nodeId = zeros(M, N); % transfer 3D coordinates into 2D index
    indexToMn = zeros(M * N, 2); % transfer 2D index to 3D coordinates
    raanDeg = (0:M-1)' * (cfg.model.raan_span_deg / M);
    phaseDeg = zeros(M, N); % the original degree of satellites

    for m = 1:M
        Omega = raanDeg(m);
        for n = 1:N
            phaseDeg(m,n) = (n-1) * 360/N + ... % 同一轨道面上的卫星均匀排开
                (m-1) * cfg.model.F * 360/(M*N); % 轨道面按照相位因子F错开
            u = phaseDeg(m,n) + ...
                cfg.orbit.argument_of_perigee_deg + angularAdvanceDeg;

            % Rz(Omega) * Rx(inclination) * [r*cos(u); r*sin(u); 0].
            % 计算卫星在轨道的3D位置
            position(m,n,1) = radiusKm * ( ...
                cosd(Omega)*cosd(u) - sind(Omega)*sind(u)*cosd(inclination));
            position(m,n,2) = radiusKm * ( ...
                sind(Omega)*cosd(u) + cosd(Omega)*sind(u)*cosd(inclination));
            position(m,n,3) = radiusKm * sind(u)*sind(inclination);

            id = (m-1)*N+n;
            nodeId(m,n) = id;
            indexToMn(id,:) = [m, n];
        end
    end

    satellites.position_eci_km = position;
    satellites.node_id = nodeId;
    satellites.index_to_mn = indexToMn;
    satellites.raan_deg = raanDeg;
    satellites.initial_phase_deg = phaseDeg;
    satellites.time_index = timeIndex;
    satellites.time_offset_s = timeOffsetS;
    satellites.coordinate_frame = 'ECI';
end
