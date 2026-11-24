function [nodes, distanceKm, delayMs] = follow_path_vector( ...
        graphs, sourceId, targetId, direction, pathVector)
%FOLLOW_PATH_VECTOR Convert 0/1 intra/inter instructions to satellite IDs.

    if ~isfield(graphs, 'distance_km') || ...
            ~isfield(graphs, 'propagation_ms') || ...
            ~isa(graphs.distance_km, 'graph') || ...
            ~isa(graphs.propagation_ms, 'graph') || ...
            any(~ismember(pathVector(:), [0,1])) || ...
            sum(pathVector == 0) ~= direction.intra_count || ...
            sum(pathVector == 1) ~= direction.inter_count
        error('Invalid graphs or 0/1 path vector.');
    end

    m = direction.source_mn(1);
    n = direction.source_mn(2);
    nodes = zeros(numel(pathVector)+1,1);
    nodes(1) = sourceId;
    for k = 1:numel(pathVector)
        if pathVector(k) == 0
            n = advance(n, direction.indicator_y, ...
                graphs.N, graphs.intra_plane_wrap);
        else
            m = advance(m, direction.indicator_x, ...
                graphs.M, graphs.inter_plane_wrap);
        end
        nodes(k+1) = (m-1)*graphs.N+n;
    end
    if nodes(end) ~= targetId
        error('Path vector does not end at the target satellite.');
    end
    if numel(nodes) == 1
        distanceKm = 0;
        delayMs = 0;
        return
    end
    edgeIds = findedge(graphs.distance_km, ...
        nodes(1:end-1), nodes(2:end));
    if any(edgeIds == 0)
        error('Path vector traverses an ISL absent from the graph.');
    end
    distanceKm = sum(graphs.distance_km.Edges.Weight(edgeIds));
    delayMs = sum(graphs.propagation_ms.Edges.Weight(edgeIds));
end

function next = advance(current, indicator, count, wraps)
    next = current + indicator;
    if wraps
        next = mod(next-1, count)+1;
    elseif next < 1 || next > count
        error('Path attempts to cross a non-wrapping constellation seam.');
    end
end
