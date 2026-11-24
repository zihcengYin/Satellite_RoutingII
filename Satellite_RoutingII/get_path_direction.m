function direction = get_path_direction(graphs, sourceId, targetId)
%GET_PATH_DIRECTION Minimum-hop directions in the (plane, satellite) grid.
%   indicator_x changes the plane index; indicator_y changes the satellite
%   index. The two-element direction_indicators row is [x, y]. A zero
%   indicator means no hop is needed in that dimension. Ties choose +1.

    needed = {'M','N','intra_plane_wrap','inter_plane_wrap','node_count'};
    if ~isstruct(graphs) || ~all(isfield(graphs, needed))
        error('graphs must be the output of build_isl_graph.');
    end
    M = graphs.M;
    N = graphs.N;
    if ~isscalar(sourceId) || ~isscalar(targetId) || ...
            ~isnumeric(sourceId) || ~isnumeric(targetId) || ...
            ~isfinite(sourceId) || ~isfinite(targetId) || ...
            sourceId ~= fix(sourceId) || targetId ~= fix(targetId) || ...
            sourceId < 1 || targetId < 1 || ...
            sourceId > M*N || targetId > M*N
        error('Source and target must be valid satellite IDs.');
    end
    sourceM = floor((sourceId-1)/N)+1;
    sourceN = mod(sourceId-1,N)+1;
    targetM = floor((targetId-1)/N)+1;
    targetN = mod(targetId-1,N)+1;
    [indicatorX, interCount] = one_direction( ...
        sourceM, targetM, M, graphs.inter_plane_wrap);
    [indicatorY, intraCount] = one_direction( ...
        sourceN, targetN, N, graphs.intra_plane_wrap);

    direction.indicator_x = indicatorX;
    direction.indicator_y = indicatorY;
    direction.direction_indicators = [indicatorX, indicatorY];
    direction.inter_count = interCount;
    direction.intra_count = intraCount;
    direction.hop_count = interCount + intraCount;
    direction.source_mn = [sourceM, sourceN];
    direction.target_mn = [targetM, targetN];
end

function [indicator, count] = one_direction(source, target, sizeOfRing, wraps)
    if source == target
        indicator = 0;
        count = 0;
    elseif ~wraps
        indicator = sign(target-source);
        count = abs(target-source);
    else
        forward = mod(target-source, sizeOfRing);
        backward = mod(source-target, sizeOfRing);
        if forward <= backward
            indicator = 1;
            count = forward;
        else
            indicator = -1;
            count = backward;
        end
    end
end
