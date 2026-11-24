function cfg = get_common_config(spec)

    required = {'name','source_profile','M','N','F','altitude_km', ...
        'inclination_deg','raan_span_deg','minimum_ground_elevation_deg'};
    for k = 1:numel(required)
        if ~isfield(spec, required{k})
            error('Missing constellation parameter: %s', required{k});
        end
    end
    if ~isscalar(spec.M) || ~isnumeric(spec.M) || ~isfinite(spec.M) || ...
            spec.M < 2 || spec.M ~= fix(spec.M) || ...
            ~isscalar(spec.N) || ~isnumeric(spec.N) || ~isfinite(spec.N) || ...
            spec.N < 2 || spec.N ~= fix(spec.N)
        error('M and N must be integers greater than or equal to 2.');
    end
    if ~isscalar(spec.F) || ~isnumeric(spec.F) || ~isfinite(spec.F) || ...
            spec.F ~= fix(spec.F) || spec.F < 0
        error('F must be a nonnegative integer.');
    end
    if ~isscalar(spec.altitude_km) || ~isnumeric(spec.altitude_km) || ...
            ~isfinite(spec.altitude_km) || spec.altitude_km <= 0 || ...
            ~isscalar(spec.inclination_deg) || ~isnumeric(spec.inclination_deg) || ...
            ~isfinite(spec.inclination_deg) || spec.inclination_deg < 0 || ...
            spec.inclination_deg > 180 || ...
            ~isscalar(spec.minimum_ground_elevation_deg) || ...
            ~isnumeric(spec.minimum_ground_elevation_deg) || ...
            ~isfinite(spec.minimum_ground_elevation_deg) || ...
            spec.minimum_ground_elevation_deg < 0 || ...
            spec.minimum_ground_elevation_deg > 90
        error('Invalid altitude, inclination, or ground elevation angle.');
    end
    if ~ismember(spec.raan_span_deg, [180, 360])
        error(' RAAN spans of 180 or 360 degrees.');
    end

    % Shared constants and snapshot settings.
    cfg.earth.radius_km = 6371;
    cfg.earth.gravitational_constant_m3_kg_s2 = 6.6743e-11;
    cfg.earth.mass_kg = 5.972e24;
    cfg.earth.mu_m3_s2 = 3.98618e14;
    cfg.light.speed_m_s = 3e8;
    cfg.light.terrestrial_speed_m_s = 2e8;
    cfg.simulation.slot_s = 2;
    cfg.simulation.duration_s = 2;
    cfg.simulation.time_index = 1; % 选择第n个采样点
    cfg.simulation.epoch_utc = [2020, 9, 20, 12, 25, 40];

    cfg.model.name = spec.name;
    cfg.model.source_profile = spec.source_profile;
    cfg.model.M = spec.M;
    cfg.model.N = spec.N;
    cfg.model.F = spec.F;
    cfg.model.total_satellites = spec.M * spec.N;
    cfg.model.inclination_deg = spec.inclination_deg;
    cfg.model.raan_span_deg = spec.raan_span_deg;
    cfg.model.raan_spacing_deg = spec.raan_span_deg / spec.M;
    cfg.model.inplane_spacing_deg = 360 / spec.N;
    cfg.model.interplane_phase_spacing_deg = ...
        spec.F * 360 / (spec.M * spec.N);
    cfg.model.minimum_ground_elevation_deg = ...
        spec.minimum_ground_elevation_deg;
    if spec.raan_span_deg == 180
        cfg.model.walker_type = 'star';
    else
        cfg.model.walker_type = 'delta';
    end

    cfg.orbit.eccentricity = 0;
    cfg.orbit.altitude_km = spec.altitude_km;
    cfg.orbit.radius_km = cfg.earth.radius_km + spec.altitude_km;
    cfg.orbit.argument_of_perigee_deg = 0; % 近地点幅角，为零时轨道为圆形
    cfg.orbit.period_s = 2 * pi * sqrt( ...
        (cfg.orbit.radius_km * 1000)^3 / ...
        (cfg.earth.gravitational_constant_m3_kg_s2 * cfg.earth.mass_kg));
    cfg.orbit.step_deg = 360 * cfg.simulation.slot_s / cfg.orbit.period_s;

    % Same-n interplane pairing and the 180-degree Walker-Star seam.
    cfg.topology.intra_plane_wrap = true;
    cfg.topology.inter_plane_wrap = spec.raan_span_deg == 360; % 只有delta星座的卫星会首尾相连
    cfg.topology.same_satellite_index_across_planes = true;
    cfg.topology.bidirectional_isl = true;
    cfg.topology.include_ground_nodes = false;
    cfg.topology.distance_unit = 'km';
    cfg.topology.delay_unit = 'ms';
end
