function graphs = build_isl_graph(cfg, links)
%BUILD_ISL_GRAPH Build hop-, distance-, and delay-weighted ISL graphs.
%   GRAPHS = BUILD_ISL_GRAPH(CFG, LINKS) returns three undirected MATLAB
%   graph objects with identical nodes and ISLs:
%     GRAPHS.hop         - every ISL has weight 1 (number of hops)
%     GRAPHS.distance_km - each ISL has weight links.length_km (km)
%     GRAPHS.propagation_ms - ISL propagation delay at cfg.light.speed_m_s
%   Node IDs are 1..M*N, matching generate_constellation and build_isl_links.
%   No ground nodes or additional ISL feasibility rules are introduced.

    if ~isstruct(cfg) || ~isfield(cfg, 'model') || ...
            ~isfield(cfg.model, 'M') || ~isfield(cfg.model, 'N') || ...
            ~isstruct(links) || ~isfield(links, 'source_id') || ...
            ~isfield(links, 'target_id') || ~isfield(links, 'length_km')
        error('Pass a constellation cfg and output from build_isl_links.');
    end

    nodeCount = cfg.model.M * cfg.model.N;
    source = links.source_id(:);
    target = links.target_id(:);
    lengthKm = links.length_km(:);
    edgeCount = numel(source);
    if ~isscalar(nodeCount) || ~isfinite(nodeCount) || ...
            nodeCount < 1 || nodeCount ~= fix(nodeCount) || ...
            numel(target) ~= edgeCount || numel(lengthKm) ~= edgeCount || ...
            any(~isfinite(source)) || any(~isfinite(target)) || ...
            any(source < 1) || any(target < 1) || ...
            any(source > nodeCount) || any(target > nodeCount) || ...
            any(source ~= fix(source)) || any(target ~= fix(target)) || ...
            any(source == target) || ...
            any(~isfinite(lengthKm)) || any(lengthKm <= 0)
        error('Invalid node IDs or nonpositive ISL lengths.');
    end
    if size(unique(sort([source, target], 2), 'rows'), 1) ~= edgeCount
        error('links contains duplicate undirected ISLs.');
    end

    if ~isfield(cfg, 'light') || ~isfield(cfg.light, 'speed_m_s') || ...
            ~isscalar(cfg.light.speed_m_s) || ...
            ~isfinite(cfg.light.speed_m_s) || cfg.light.speed_m_s <= 0
        error('cfg.light.speed_m_s must be a positive scalar.');
    end
    delayMs = lengthKm * 1e6 / cfg.light.speed_m_s;
    graphs.hop = graph(source, target, ones(edgeCount,1), nodeCount);
    graphs.distance_km = graph(source, target, lengthKm, nodeCount);
    graphs.propagation_ms = graph(source, target, delayMs, nodeCount);
    graphs.speed_m_s = cfg.light.speed_m_s;
    graphs.node_count = nodeCount;
    graphs.edge_count = edgeCount;
    graphs.M = cfg.model.M;
    graphs.N = cfg.model.N;
    graphs.intra_plane_wrap = cfg.topology.intra_plane_wrap;
    graphs.inter_plane_wrap = cfg.topology.inter_plane_wrap;
end
