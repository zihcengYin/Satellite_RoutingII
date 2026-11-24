function links = build_isl_links(cfg, satellites)
%BUILD_ISL_LINKS Build unique undirected intra/inter-plane ISLs.
%   LINKS = BUILD_ISL_LINKS(CFG, SATELLITES) uses the same-n adjacent-plane
%   topology. Each row is one physical link;

    if ~isstruct(cfg) || ~isfield(cfg, 'model') || ...
            ~isfield(cfg, 'topology') || ~isstruct(satellites) || ...
            ~isfield(satellites, 'position_eci_km') || ...
            ~isfield(satellites, 'node_id') || ...
            ~isfield(satellites, 'index_to_mn')
        error('Pass a valid cfg and the output of generate_constellation.');
    end
    M = cfg.model.M;
    N = cfg.model.N;
    pos = satellites.position_eci_km;
    ids = satellites.node_id;
    if ~isequal(size(pos), [M, N, 3]) || ...
            ~isequal(size(ids), [M, N]) || ...
            ~isequal(size(satellites.index_to_mn), [M*N, 2]) || ...
            any(~isfinite(pos(:))) || ...
            ~isequal(ids, reshape(1:M*N, N, M)')
        error('Satellite coordinates or IDs do not match cfg.model.M/N.');
    end
    needed = {'intra_plane_wrap', 'inter_plane_wrap', ...
        'same_satellite_index_across_planes', 'bidirectional_isl'};
    for k = 1:numel(needed)
        if ~isfield(cfg.topology, needed{k})
            error('cfg.topology.%s is required.', needed{k});
        end
    end
    if ~cfg.topology.same_satellite_index_across_planes || ...
            ~cfg.topology.bidirectional_isl
        error('Only undirected, same-n inter-plane links are supported.');
    end

    % At most M*N intra-plane plus M*N inter-plane candidate edges.
    source = zeros(2*M*N, 1);
    target = zeros(2*M*N, 1);
    edgeType = strings(2*M*N, 1);
    count = 0;

    for m = 1:M
        for n = 1:N
            if n == N && ~cfg.topology.intra_plane_wrap
                continue
            end
            nextN = mod(n, N) + 1;
            count = count + 1;
            source(count) = ids(m,n);
            target(count) = ids(m,nextN);
            edgeType(count) = "intra";
        end
    end

    for m = 1:M
            if m == M && ~cfg.topology.inter_plane_wrap
                continue
            end
            nextM = mod(m, M) + 1;
        for n = 1:N
            count = count + 1;
            source(count) = ids(m,n);
            target(count) = ids(nextM,n);
            edgeType(count) = "inter";
        end
    end

    % A two-node ring proposes the same physical edge twice. Normalize
    % endpoints and remove duplicates, while preserving edge-type order.
    endpoints = sort([source(1:count), target(1:count)], 2);
    [endpoints, keep] = unique(endpoints, 'rows', 'stable');
    edgeType = edgeType(keep);

    % Reorder [M,N,3] to [M*N,3] in the same order as node_id.
    xyz = reshape(permute(pos, [2,1,3]), [], 3);
    delta = xyz(endpoints(:,1),:) - xyz(endpoints(:,2),:); % (Δx, Δy, Δz)
    lengthKm = sqrt(sum(delta.^2, 2)); % distance between src & tar

    links.source_id = endpoints(:,1);
    links.target_id = endpoints(:,2);
    links.source_mn = satellites.index_to_mn(links.source_id,:);
    links.target_mn = satellites.index_to_mn(links.target_id,:);
    links.type = edgeType;
    links.length_km = lengthKm;
    links.intra_count = sum(edgeType == "intra");
    links.inter_count = sum(edgeType == "inter");
    links.coordinate_frame = 'ECI';
end
