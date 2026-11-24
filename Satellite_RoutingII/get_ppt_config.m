function cfg = get_ppt_config(modelName)

    if nargin < 1 || isempty(modelName)
        modelName = 'Design';  % Final active selection in the source script.
    end
    if ~(ischar(modelName) || (isstring(modelName) && isscalar(modelName)))
        error('modelName must be a character vector or scalar string.');
    end
    modelName = char(modelName);
    spec.name = modelName;
    spec.source_profile = 'ppt';
    spec.F = 6;
    switch modelName
        case 'DesignPolar'
            spec.M = 10; spec.N = 20;
            spec.altitude_km = 550;
            spec.inclination_deg = 86;
            spec.raan_span_deg = 180;
            spec.minimum_ground_elevation_deg = 25;
        case 'Design'
            spec.M = 10; spec.N = 30;
            spec.altitude_km = 550;
            spec.inclination_deg = 60;
            spec.raan_span_deg = 360;
            spec.minimum_ground_elevation_deg = 25;
        case 'Starlink'
            spec.M = 72; spec.N = 22;
            spec.altitude_km = 550;
            spec.inclination_deg = 53;
            spec.raan_span_deg = 360;
            spec.minimum_ground_elevation_deg = 25;
        case 'Iridium'
            spec.M = 6; spec.N = 11;
            spec.altitude_km = 780;
            spec.inclination_deg = 86;
            spec.raan_span_deg = 180;
            spec.minimum_ground_elevation_deg = 8.2;
        case 'Kuiper'
            spec.M = 34; spec.N = 34;
            spec.altitude_km = 630;
            spec.inclination_deg = 51.9;
            spec.raan_span_deg = 360;
            spec.minimum_ground_elevation_deg = 20;
        case 'OneWeb'
            spec.M = 18; spec.N = 40;
            spec.altitude_km = 1200;
            spec.inclination_deg = 88;
            spec.raan_span_deg = 180;
            spec.minimum_ground_elevation_deg = 20;
        otherwise
            error('Unknown PPT constellation: %s', modelName);
    end
    cfg = get_common_config(spec);
end
