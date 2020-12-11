%% Import pupil DeepLabCut data

PupilData = importPupilCSV('C:\Users\Evan\Box Sync\Data\Pupil\20190112\DT134_20190112_000_2019-01-12-105315-0000DeepCut_resnet50_DT_PupilTrack_2019011220190112shuffle1_1030000.csv');

%% Export for imagej

tmpPupil = table2array(PupilData);
ImJ_export = [];
for i = 1:size(tmp,1)
    ImJ_export = vertcat(ImJ_export,[tmpPupil(i,1:2:16)' tmpPupil(i,2:2:16)' ones(8,1)*i]);
end
ImJ_export = [(1:size(ImJ_export, 1))' ImJ_export];

headers = {'', 'X', 'Y', 'Slice'};
csvwrite_with_headers('test.csv',ImJ_export, headers)

%%
headers = {'', 'X', 'Y', 'Slice'};
csvwrite_with_headers('test.csv',ImJ_export, headers)

%% 

pupil_tmp = (PupilData.Pupil_Left_X + PupilData.Pupil_Right_X)/2;
reflection_tmp = (PupilData.Reflection_Left_X + PupilData.Reflection_Right_X)/2;

PupilTrace = pupil_tmp - reflection_tmp;

eyelid_distance = PupilData.Eyelid_Bottom_Y - PupilData.Eyelid_Top_Y;

plot(pupil_tmp)
hold on
plot(reflection_tmp)

%%

plot(PupilTrace)
hold on
plot(eyelid_distance)

%%
plot(eyelid_distance)



