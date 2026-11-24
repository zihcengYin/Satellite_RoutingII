function results = test_routing_paths()
%TEST_ROUTING_PATHS Check hop, Dijkstra, high-latitude, and random routes.
%   Also verifies that the 3D plot hides orange inter-plane ISLs by default.

    previousRng = rng;
    restoreRng = onCleanup(@() rng(previousRng)); %#ok<NASGU>
    rng(2026);
    configs = {get_routing_config('Design'), ...
        get_ppt_config('Design'), get_routing_config('Iridium')};
    results = struct([]);
    for caseNo = 1:numel(configs)
        cfg = configs{caseNo};
        satellites = generate_constellation(cfg);
        links = build_isl_links(cfg, satellites);
        graphs = build_isl_graph(cfg, links);
        if cfg.topology.inter_plane_wrap
            sourceMn = [cfg.model.M, 5];
            targetMn = [1, 8];
        else
            sourceMn = [1, 5];
            targetMn = [cfg.model.M, 8];
        end
        sourceId = satellites.node_id(sourceMn(1),sourceMn(2));
        targetId = satellites.node_id(targetMn(1),targetMn(2));
        hop = find_hop_min_path(graphs, sourceId, targetId);
        distance = find_distance_min_path(graphs, sourceId, targetId);
        highLatitude = find_high_latitude_path( ...
            cfg, satellites, graphs, sourceId, targetId);
        weighted = find_alpha_latitude_path( ...
            cfg, satellites, graphs, sourceId, targetId, 0.05);

        assert(hop.node_ids(end) == targetId);
        assert(weighted.node_ids(end) == targetId);
        assert(highLatitude.node_ids(end) == targetId);
        assert(numel(hop.path_vector) == hop.hop_count);
        assert(numel(weighted.path_vector) == weighted.hop_count);
        assert(hop.hop_count == weighted.hop_count);
        assert(hop.hop_count == highLatitude.hop_count);
        assert(isequal(highLatitude.candidate_mean_abs_latitude_deg, ...
            weighted.mean_abs_latitude_deg));
        if highLatitude.indicator_x ~= 0
            [~, bestPosition] = max( ...
                highLatitude.candidate_mean_abs_latitude_deg);
            assert(highLatitude.selected_intra_hops == bestPosition-1);
        end
        assert(abs(sum(weighted.selection_probability)-1) < 1e-12);
        [~, mostLikely] = max(weighted.selection_probability);
        [~, highestLatitude] = max(weighted.mean_abs_latitude_deg);
        assert(mostLikely == highestLatitude);
        assert(distance.distance_km <= weighted.distance_km + 1e-8);
        assert(distance.distance_km <= highLatitude.distance_km + 1e-8);
        assert(abs(weighted.propagation_delay_ms - ...
            weighted.distance_km*1e6/cfg.light.speed_m_s) < 1e-8);
        assert(hop.indicator_x == 1 && hop.indicator_y == 1);

        results(caseNo).profile = cfg.model.source_profile; %#ok<AGROW>
        results(caseNo).model = cfg.model.name;
        results(caseNo).hop_count = hop.hop_count;
        results(caseNo).shortest_distance_km = distance.distance_km;
        results(caseNo).weighted_distance_km = weighted.distance_km;
        results(caseNo).high_latitude_distance_km = ...
            highLatitude.distance_km;
        results(caseNo).direction_indicators = hop.direction_indicators;
        results(caseNo).hop_path_vector = hop.path_vector;
        results(caseNo).alpha_path_vector = weighted.path_vector;
        results(caseNo).candidate_mean_latitude_deg = ...
            weighted.mean_abs_latitude_deg;
        results(caseNo).alpha_probabilities = ...
            weighted.selection_probability;
        fprintf('%s/%s: hop=%d, Dijkstra=%.2f km, ', ...
            cfg.model.source_profile, cfg.model.name, hop.hop_count, ...
            distance.distance_km);
        fprintf('high-lat=%.2f km, alpha=%.2f km.\n', ...
            highLatitude.distance_km, weighted.distance_km);

        if caseNo == 1
            fig = plot_constellation_3d(cfg, satellites, links, hop);
            interLine = findobj(fig, 'Type', 'line', ...
                'Color', [0.95, 0.49, 0.10]);
            assert(~isempty(interLine) && ...
                strcmp(interLine(1).Visible, 'off'));
            close(fig);
            fig = plot_constellation_3d( ...
                cfg, satellites, links, hop, true);
            interLine = findobj(fig, 'Type', 'line', ...
                'Color', [0.95, 0.49, 0.10]);
            assert(~isempty(interLine) && ...
                strcmp(interLine(1).Visible, 'on'));
            close(fig);
        end
        for trial = 1:30
            randomSource = randi(graphs.node_count);
            randomTarget = randi(graphs.node_count);
            trialHop = find_hop_min_path( ...
                graphs, randomSource, randomTarget);
            trialHigh = find_high_latitude_path( ...
                cfg, satellites, graphs, randomSource, randomTarget);
            trialAlpha = find_alpha_latitude_path( ...
                cfg, satellites, graphs, randomSource, randomTarget);
            [~, referenceHops] = shortestpath( ...
                graphs.hop, randomSource, randomTarget);
            assert(trialHop.hop_count == referenceHops);
            assert(trialAlpha.hop_count == referenceHops);
            assert(trialHigh.hop_count == referenceHops);
            assert(trialAlpha.node_ids(end) == randomTarget);
            assert(trialHigh.node_ids(end) == randomTarget);
            trialDirection = get_path_direction( ...
                graphs, randomSource, randomTarget);
            assert(sum(trialAlpha.path_vector == 1) == ...
                trialDirection.inter_count);
        end
    end
end
