function results = test_constellation_3d()
%TEST_CONSTELLATION_3D Compare four routing strategies for Design.
%   Run TEST_CONSTELLATION_3D from Satellite_RoutingII. The first 3D figure
%   highlights the minimum-hop route; the second highlights the global
%   minimum-distance route; the third shows the deterministic high-latitude
%   construction; the fourth shows a latitude-weighted random route.
%   The fifth figure checks ISL length by latitude.

    cfg = get_ppt_config('Design');  % Delta: M=10, N=30, F=6.
    satellites = generate_constellation(cfg);
    links = build_isl_links(cfg, satellites);
    graphs = build_isl_graph(cfg, links);
    sourceMn = [10,5]; %(m1,n1)
    targetMn = [1,8]; %(m2,n2)
    sourceId = satellites.node_id(sourceMn(1),sourceMn(2));
    targetId = satellites.node_id(targetMn(1),targetMn(2));
    route = find_hop_min_path(graphs, sourceId, targetId);
    distanceRoute = find_distance_min_path(graphs, sourceId, targetId);
    highLatitudeRoute = find_high_latitude_path( ...
        cfg, satellites, graphs, sourceId, targetId);
    alpha = 0.05; % Positive, in inverse degrees.
    rng('shuffle'); % Vary samples even after restarting MATLAB.
    alphaRoute = find_alpha_latitude_path( ...
        cfg, satellites, graphs, sourceId, targetId, alpha);
    if distanceRoute.distance_km > route.distance_km + 1e-8
        error('Distance-min route is longer than the hop-min route.');
    end
    if highLatitudeRoute.node_ids(end) ~= targetId || ...
            highLatitudeRoute.hop_count ~= route.hop_count || ...
            distanceRoute.distance_km > highLatitudeRoute.distance_km + 1e-8
        error('High-latitude constructed route failed validation.');
    end
    if alphaRoute.node_ids(end) ~= targetId || ...
            alphaRoute.hop_count ~= route.hop_count || ...
            distanceRoute.distance_km > alphaRoute.distance_km + 1e-8
        error('Latitude-weighted route failed endpoint or distance checks.');
    end

    intra = links.type == "intra";
    inter = links.type == "inter";
    intraLengths = links.length_km(intra);
    interLengths = links.length_km(inter);
    if links.intra_count ~= cfg.model.M*cfg.model.N || ...
            links.inter_count ~= cfg.model.M*cfg.model.N
        error('Unexpected link counts for the Design Delta constellation.');
    end

    intraSpreadKm = max(intraLengths)-min(intraLengths);
    interSpreadKm = max(interLengths)-min(interLengths);
    if intraSpreadKm > 1e-6
        error('Intra-plane ISLs are not equal in length.');
    end
    if interSpreadKm < 1e-3
        error('Inter-plane ISLs do not vary in length.');
    end

    % Use midpoint latitude only as a geometric diagnostic. It is not
    % Earth-fixed geographic latitude and requires no ECI/ECEF transform.
    xyz = reshape(permute(satellites.position_eci_km, [2,1,3]), [], 3);
    midpoint = (xyz(links.source_id(inter),:) + ...
        xyz(links.target_id(inter),:))/2;
    absLatitudeDeg = abs(atan2d(midpoint(:,3), ...
        hypot(midpoint(:,1), midpoint(:,2))));
    % 计算整个星座高纬和低纬距离差距
    lowLengths = interLengths(absLatitudeDeg <= 15); % 两个相邻异轨卫星中点的纬度值
    highLengths = interLengths(absLatitudeDeg >= 45);
    if isempty(lowLengths) || isempty(highLengths)
        error('Not enough low/high-latitude inter-plane ISLs to compare.');
    end
    lowMeanKm = mean(lowLengths);
    highMeanKm = mean(highLengths);
    if highMeanKm >= lowMeanKm
        error('High-latitude inter-plane ISLs are not shorter on average.');
    end

    plot_constellation_3d(cfg, satellites, links, route);
    plot_constellation_3d(cfg, satellites, links, distanceRoute);
    plot_constellation_3d(cfg, satellites, links, highLatitudeRoute);
    plot_constellation_3d(cfg, satellites, links, alphaRoute);

    figure('Name', 'ISL length versus latitude', 'Color', 'w');
    hold on;
    scatter(absLatitudeDeg, interLengths, 22, ...
        [0.77, 0.22, 0.20], 'filled', ...
        'DisplayName', 'Inter-plane ISLs');
    yline(intraLengths(1), '--', 'Color', [0.95, 0.64, 0.15], ...
        'LineWidth', 1.4, 'DisplayName', 'Intra-plane length');
    grid on;
    xlabel('Absolute geocentric midpoint latitude (deg)');
    ylabel('Straight-line ISL length (km)');
    title('Design Delta: inter-plane links shorten at high latitude');
    legend('Location', 'best');

    fprintf('Intra-plane: %d links, length %.3f km, spread %.3g km.\n', ...
        links.intra_count, mean(intraLengths), intraSpreadKm);
    fprintf('Inter-plane: %d links, min %.3f km, max %.3f km.\n', ...
        links.inter_count, min(interLengths), max(interLengths));
    fprintf('Inter-plane mean: |lat|<=15 deg %.3f km; ', lowMeanKm);
    fprintf('|lat|>=45 deg %.3f km.\n', highMeanKm);
    fprintf('Hop-min route (%d,%d) -> (%d,%d): %d hops, %.3f km.\n', ...
        sourceMn, targetMn, route.hop_count, route.distance_km);
    fprintf('Distance-min route (%d,%d) -> (%d,%d): %d hops, ', ...
        sourceMn, targetMn, distanceRoute.hop_count);
    fprintf('%.3f km, %.3f ms propagation.\n', ...
        distanceRoute.distance_km, distanceRoute.propagation_delay_ms);
    fprintf('Distance saved relative to hop-min: %.3f km.\n', ...
        route.distance_km - distanceRoute.distance_km);
    sameAsDijkstra = isequal( ...
        highLatitudeRoute.node_ids(:), distanceRoute.node_ids(:));
    fprintf('High-latitude route: %d hops, %.3f km, %.3f ms; ', ...
        highLatitudeRoute.hop_count, highLatitudeRoute.distance_km, ...
        highLatitudeRoute.propagation_delay_ms);
    fprintf('selected after %d intra hops (mean |lat| %.3f deg).\n', ...
        highLatitudeRoute.selected_intra_hops, ...
        highLatitudeRoute.selected_mean_abs_latitude_deg);
    fprintf('Compared with Dijkstra: same node path=%d, ', sameAsDijkstra);
    fprintf('extra distance=%.3f km.\n', ...
        highLatitudeRoute.distance_km-distanceRoute.distance_km);
    fprintf('Latitude-weighted random route (alpha=%.3f /deg): ', alpha);
    fprintf('%d hops, %.3f km, %.3f ms propagation.\n', ...
        alphaRoute.hop_count, alphaRoute.distance_km, ...
        alphaRoute.propagation_delay_ms);

    % Each row is one candidate point on the source orbital plane after
    % i intra-plane hops. The mean latitude covers the planes crossed next.
    candidateI = (0:numel(alphaRoute.selection_probability)-1)';
    candidateN = mod(sourceMn(2)-1 + ...
        candidateI*alphaRoute.indicator_y, cfg.model.N)+1;
    probabilityTable = table(candidateI, ...
        repmat(sourceMn(1), numel(candidateI), 1), candidateN, ...
        alphaRoute.mean_abs_latitude_deg, ...
        alphaRoute.selection_probability, ...
        'VariableNames', {'IntraHopsBeforeInter', 'PlaneM', ...
        'SatelliteN', 'MeanAbsLatitudeDeg', 'Probability'});
    disp(probabilityTable);
    fprintf('Selected inter-hop locations after intra hops: [%s].\n', ...
        num2str(alphaRoute.inter_locations_after_intra_hops'));
    fprintf('Random path vector (0=intra, 1=inter): [%s].\n', ...
        num2str(alphaRoute.path_vector'));

    results.intra_count = links.intra_count;
    results.inter_count = links.inter_count;
    results.intra_spread_km = intraSpreadKm; % max-min (轨内误差）
    results.inter_spread_km = interSpreadKm; % max-min
    results.low_latitude_inter_mean_km = lowMeanKm;
    results.high_latitude_inter_mean_km = highMeanKm;
    results.route = route;
    results.distance_route = distanceRoute;
    results.high_latitude_route = highLatitudeRoute;
    results.high_latitude_same_as_dijkstra = sameAsDijkstra;
    results.high_latitude_extra_km = ...
        highLatitudeRoute.distance_km-distanceRoute.distance_km;
    results.alpha_route = alphaRoute;
    results.alpha_probability_table = probabilityTable;
end
