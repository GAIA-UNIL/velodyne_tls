%% Travail de Master Jason Bula : Velodyne VLP16 
clear, close all
%% r�pertoire des scans bruts
%gestion des r�pertoires

% R�pertoire o� sont stock� les fichiers .pcap
input = 'C:\Users\jason\Desktop\calibration';

% R�pertoire ou le r�sultat est enregistr�
output ='C:\Users\jason\Desktop\calibration\result';
% Nom du fichier .pcap
input_file_name = 'geop.pcap';
% Nom du fichier � enregistrer
output_file_name = 'geop';


cd(input)

%% Initialisation des param�tres propre � la prise de mesures
% ouverture d'un scan
veloReader = velodyneFileReader(input_file_name,'VLP16'); 

times = 3600; % Temps de l'aquisition
angle = 360; % Angle de rotation du LiDAR
first = 195; % Temps � la premi�re image

%% Param�tres modifiables
% Mettre � 0 pour une calibration ou � 1 pour s�lectionner seulement les
% points positifs sur l'axe x
pos = 1; 

% Il peut �tre utile d'enregistrer seulemement les bandes 1 et 16 pour
% montrer l'effet de la calibration. Si pos2 = 1, toutes les bandes sont
% enregistr�es, si pos2 = 0, seuls les bandes 1 et 16 sont enregistr�es
pos2 = 1;

%Il est possible de modifier la r�solution du fichier de sortie. Si ce
%param�tres est = � 0, tous les points sont conserv�s
gridStep = 0; 

%%
last = first +times; % Temps � la derni�res image

angle_deg=(0:angle/times:angle); % Angle de rotation apr�s chaque image
angle = deg2rad(angle_deg); % transformation en radian

% Angles de correcion alpha 1 et alpha 2. Fix� � 0 en l'absence de
% calibration
alpha_ini= [0.36 0];

% Il s'agit de des angles correctifs entre la verticale dans le
% r�f�rentiel du LiDAR et la verticale r�elle 

alpha_1 = alpha_ini(1);
alpha_2 = alpha_ini(2);

% Il s'agit de la longueur du bras �quivalent � la distance entre le centre
% optique du LiDAR et le centre de rotation.
R = 0;





% optionnel, en cas de disfonctionnement du moteur (initial = 0)
theta3 = -0.60;


%% Correction du nuage de points � appliquer lors de la rotation

% Dans cette partie du code, le scan va �tre extrait image apr�s image afin
% d'appliquer la correction n�cessaire pour r�aligner le nuage de points.
% Tout d'abords, seuls les images contenant des coordonn�es positives sur X
% vont �tre conserv�es, ensuite chaque image va �tre trait�e s�par�ment.
% Deux matrices de transformation seront appliqu�es � chaque image. Une
% contenant la rotation selon l'angle du LiDAR (varie au fil du temps) et
% l'autre, une translation appliqu�e correspondant au la distance entre le
% bras et le centre optique du LiDAR. Cette distance � �t� mesur�e
% manuellement et correspond � un d�placement sur z de R = 0.093m (peut
% �tre am�lior�). Enfin, chaque image est enregistr�e s�par�ment dans un
% Cell. 

s = 0;
for i = 2 : length(angle) % le code tourne autant de fois qu'il y a d'images
    NF = first + s;
     ptCloudIn = readFrame(veloReader,NF); % S�lection des images s�par�ment

% s�lectionne ou non le total des points du scan   
if pos == 1     
     ptCloudIn3 =  ptCloudIn.Location(1,:,1);
     ptCloudIn2 = ptCloudIn3(ptCloudIn3 <=0); % S�lection des points positifs
     
     % Remplacement des dans le nuage de points de base
     ptCloudIn =  pointCloud(ptCloudIn.Location(:,1:length(ptCloudIn2),:)); 
end  

clear ptCloudIn2 ptCloudIn3 
%% Transformation de chaque image
% D�finition des matrices de transformation
% Les matrices A1 et A2 correspondent permettent d'adapter la verticale
% (param�tres alpha 1 et alpha2)

% Correction de l'alignement en fonction de la vitesse du moteur
VM = [cos(angle(i)) 0 sin(angle(i)) 0; 0 1 0 0; -sin( angle(i)) 0 ...
      cos(angle(i)) 0; 0 0 0 1];
 
A1 = [1 0 0 0; 0 cosd(alpha_1) sind(alpha_1) 0 ; ...
      0 -sind(alpha_1) cosd(alpha_1) 0 ; 0 0 0 1];  
  
A2 =  [cosd(alpha_2) sind(alpha_2) 0 0; ...
     -sind(alpha_2) cosd(alpha_2) 0 0; 0 0 1 0; 0 0 0 1];
 
% La matrice T correspond � la matrice qui permet une translation de chacun
% des points afin d'enlever la longueur du bras (param�tre R)  
T = [1 0 0 0; 0 1 0 0; 0 0 1 0; 0 0 R 1];

% Ajustement de la vitesse du moteur  
T4 = [cosd(theta3) sind(theta3) 0 0; ...
     -sind(theta3) cosd(theta3) 0 0; 0 0 1 0; 0 0 0 1];
 
% Application des transformations aux nuages de points
tform_T = affine3d(T);
ptCloudIn = pctransform(ptCloudIn,tform_T);

tform_A1 = affine3d(A1);
ptCloudIn = pctransform(ptCloudIn,tform_A1);

tform_A2 = affine3d(A2);
ptCloudIn = pctransform(ptCloudIn,tform_A2);

tform_T = affine3d(T4);
curr_img = pctransform(ptCloudIn,tform_T); %configuration 2

tform_R = affine3d(VM);
Nuage{i-1} = pctransform(curr_img,tform_R); % enregistrement dans un cell

s = s + 1; % possible de changer

end
%disp('Transformations done') % premi�re �tape termin�e

% Le code qui suit permet d'extraire chacun des nuages de points enregistr�
% Les diff�rentes boucles pr�sentes dans le codes permettent d'acc�lerer le
% proc�essus d'enregistrement des nuages de points. Les 16 bandes peuvent �tre
% enregistr�es s�par�ments ou toutes ensembles. Une fois tous les nuages de
% points extrait, un assemblage est effect�

% Enregistrement de toutes les bandes ou seulement de la bande 1 et 16
if pos2 == 1
    bandNumber = 16;
else
    bandNumber = 2;
end


%% Le code qui suit permet de regrouper toutes les images en 1 seul nuage 
%de point. Les bandes sont enregistr�es s�parar�menent mais peuvent �tre � 
%fusionn�es apr�s coup.

for bande_sep = 1 : bandNumber
    
if pos2 == 1 
    iiii=bande_sep;
else 
    
    Bande_calibration = [1 16];
    iiii = Bande_calibration(bande_sep);
end


% Initialisation des variables
x = [];
y = [];
z = [];

X_ref = [];
Y_ref = [];
Z_ref = [];

X_ref_final = [];
Y_ref_final = [];
Z_ref_final = [];

% Acc�l�ration du processus en combinant plusieurs boucles
for iii = 1 : 10 
    for ii = (times/10*iii)-((times/10)-1) : iii*times/10     
     for i = iiii:iiii % enregistrement des bandes s�par�ments

% Suppression des anciennes valeurs
        x1 = [];
        y1 = [];
        z1 = [];
  
% S�lection des points dans les bon emplacement des matrice
% Les nuages de points sont enregistr�s sous la forme suivante : 16*1800*3
% 16 correspond � la bande, 1800 correspond au nombre de points enregistr�s
% par bande, 3 correspond aux valeurs x y et z.

x1(i,:) = Nuage{1,ii}.Location(i,:,1);
y1(i,:) = Nuage{1,ii}.Location(i,:,2);
z1(i,:) = Nuage{1,ii}.Location(i,:,3);


x = [x x1(i,:)];
y = [y y1(i,:)];
z = [z z1(i,:)];



    end 
    X_ref = [X_ref x];
    Y_ref = [Y_ref y];
    Z_ref = [Z_ref z];

    x = 0;
    y = 0;
    z = 0;
    end
    X_ref_final = [X_ref_final X_ref];
    Y_ref_final = [Y_ref_final Y_ref];
    Z_ref_final = [Z_ref_final Z_ref];
    
 disp(iii) % Compteur de progression de l'extraction 
    X_ref = 0;
    Y_ref = 0;
    Z_ref = 0;
end
        
% disp('Extraction done')

%% Enregistrement de l'ensemble de nuage de point
ref = [X_ref_final; Y_ref_final; Z_ref_final]'; 
PC_corr1 = pointCloud(ref);


%% Post-traitement du nuage de point
% Les lignes suivantes permettent d'effectuer un traitement du nuages de
% points. 
 
% Tout d'abord, le bruit va 'etre retir� avec la fonction
% 'denoise'. Cette fonction �tant assez longue peut �tre d�sctiv�es si le 
% r�sultat doit �tre affich� rapidement. 

% Le retrait du bruit a finalement �t� effectu� sur CloudCompare qui a
% permis d'obtenir de meilleurs r�sultats 

%PC_corr1 = pcdenoise(PC_corr1);
% disp('denoise done')

% Ensuite, le nuage de point va �tre r�duit � la r�solution souhait�e. En
% effet, les zones se trouvant tr�s proches du LiDAR comporteront une
% grande r�solution tandis que les zones �loign�es du LiDAR auront une
% r�solution r�duite. C'est pourquoi un ajustement de la r�solution va
% permettre une r�duction de la quantit� de donn�es sans impacter sur la
% qualit� (selon la r�solution). 

 
if gridStep == 0
    PC_downsampled_1 = PC_corr1;
else
    PC_downsampled_1 = pcdownsample(PC_corr1,'gridAverage',gridStep);
end

%disp('downsampled done')

% Cette partie du code permet de retirer les points ne comportant pas de
% donn�es
[PC_Final1,indices]= removeInvalidPoints(PC_downsampled_1);
%disp('removeInvalidPoints done')

%% Exportation du nuage de point
% Dans cette partie du code, le nuage de point est export� 

% D�finition des noms des documents en sortie
Nom_fichier = sprintf([output_file_name num2str(iiii)]); 

%acc�s au r�pertoire de sortie
cd(output)
pcwrite(PC_Final1,Nom_fichier,'PLYFormat','binary');

% retour dans le repertoire des fichier captures
cd(input)
ref = []; % suppression du nuage de point charg�

end
disp('Termin�')



