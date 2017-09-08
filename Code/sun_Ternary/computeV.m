function [sNewSource, sNewDestination, sNewWeights] = computeV( superpixels, centres, colours, labels)

   
    [ sSource, sDestination ] = ...  %  sSource�� sDestination������������
        getSpatialConnections( superpixels, labels );
   
   

    sSqrColourDistance = sum( ( colours( sSource + 1, : ) - ... % c�����У������±��0��ʼ������Ҫ��1
        colours( sDestination + 1, : ) ) .^ 2, 2 ) ;
    sCentreDistance = sqrt( sum( ( centres( sSource + 1, : ) - ...
        centres( sDestination + 1, : ) ) .^ 2, 2 ) );
    
    % t�������ԣ�����/warp����һ���飩���������꣩�������Ѿ����

    sBeta = 1.5 / mean( sSqrColourDistance ./ sCentreDistance );
 
    sWeights = exp( -sBeta * sSqrColourDistance ) ./ sCentreDistance;

    sNewSource =  sSource;
    sNewDestination = sDestination;
    sNewWeights = sWeights;