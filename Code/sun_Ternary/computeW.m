function [tNewSource, tNewDestination, tNewWeights] = computeW( superpixels, flow, colours, labels)

   
    [ tSource, tDestination, tConnections ] = ...  %  tConnections: ���ʣ� t�������ԣ�����/warp����һ���飩���������꣩
        getTemporalConnections( flow, superpixels, labels );

   
    
    % t�������ԣ�����/warp����һ���飩���������꣩�������Ѿ����
    tSqrColourDistance = sum( ( colours( tSource + 1, : ) - ...
        colours( tDestination + 1, : ) ) .^ 2, 2 ) ;

    tBeta = 1.5 / mean( tSqrColourDistance .* tConnections );

    tWeights = tConnections .* exp( -tBeta * tSqrColourDistance );
    
    tNewSource =  tSource;
    tNewDestination = tDestination;
    tNewWeights = tWeights;