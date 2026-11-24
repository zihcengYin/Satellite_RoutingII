function results = test_constellation_2d()
%TEST_CONSTELLATION_2D Show Design ISLs and a minimum-hop route on a map.
%   Source: satellite (m1,n1). Target: satellite (m2,n2).

    cfg = get_ppt_config('Design');
    satellites = generate_constellation(cfg);
    links = build_isl_links(cfg, satellites);
    graphs = build_isl_graph(cfg, links);

    sourceMn = [1,1]; % (m1,n1)
    targetMn = [10,1]; % (m2,n2)
    sourceId = satellites.node_id(sourceMn(1),sourceMn(2));
    targetId = satellites.node_id(targetMn(1),targetMn(2));
    route = find_hop_min_path(graphs, sourceId, targetId);
    fig = plot_constellation_2d(cfg, satellites, links, route);

    fprintf('Design hop-min route (%d,%d) -> (%d,%d): ', ...
        sourceMn, targetMn);
    fprintf('%d hops, %.3f km.\n', route.hop_count, route.distance_km);
    fprintf('Satellite IDs: %s\n', mat2str(route.node_ids));

    results.route = route;
    results.figure = fig;
end
