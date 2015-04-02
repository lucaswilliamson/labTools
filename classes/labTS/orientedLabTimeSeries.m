classdef orientedLabTimeSeries  < labTimeSeries
    
    %%
    properties(SetAccess=private)
        orientation %orientationInfo object
    end
    %properties(Dependent)
    %    labelPrefixes
    %    labelSuffixes
    %end

    
    %%
    methods
        
        %Constructor:
        function this=orientedLabTimeSeries(data,t0,Ts,labels,orientation) %Necessarily uniformly sampled
            if nargin<1
                data=[];
                t0=[];
                Ts=[];
                labels={};
                orientation=orientationInfo();
            end
                if ~checkLabelSanity(labels)
                    error('orientedLabTimeSeries:Constructor','Provided labels do not pass the sanity check. See issued warnings.')
                end
                this@labTimeSeries(data,t0,Ts,labels);
                if isa(orientation,'orientationInfo')
                    this.orientation=orientation;
                else
                    ME=MException('orientedLabTimeSeries:Constructor','Orientation parameter is not an OrientationInfo object.');
                    throw(ME)
                end
        end
        
        %-------------------
        
        %Other I/O functions:
        function [newTS,auxLabel]=getDataAsTS(this,label)
            [data,time,auxLabel]=getDataAsVector(this,label);
            newTS=orientedLabTimeSeries(data,time(1),this.sampPeriod,auxLabel,this.orientation);
        end

        function [data,label]=getOrientedData(this,label)
            [T,N]=size(this.Data);
            if nargin<2 || isempty(label)
                extendedLabels=addLabelSuffix(label);
            else
                extendedLabels=this.labels;
                if ~orientedLabTimeSeries.checkLabelSanity(this.labels)
                   error('Labels in this object do not pass the sanity check.') 
                end
            end
            data=this.getDataAsVector(extendedLabels);
            data=permute(reshape(data,T,3,round(N/3)),[1,3,2]);
        end
        
        function [diffMatrix,labels,labels2,Time]=computeDifferenceMatrix(this,t0,t1,labels,labels2)
           %Computes the difference vector between two markers, for the time interval [t0,t1] 
           %If labels is specified, only those markers are used
           %If labels2 is specified, distance to those markers only is
           %specified
           [data,label]=getOrientedData(this,this.getLabelPrefix);
           [T,N,M]=size(data); %M=3
           
           %Inefficient way: compute the difference matrix for all times
           %and markers, and then reduce it
           diffMatrix=nan(T,N,M,N);
           for i=1:N
               diffMatrix(:,:,:,i)= bsxfun(@minus,data,data(:,i,:));
           end
           diffMatrix=permute(diffMatrix,[1,2,4,3]);
           if nargin<2 || isempty(t0)
              t0=this.Time(1); 
           end
           if nargin<3 || isempty(t1)
               t1=this.Time(end)+eps;
           end
           if nargin<4 || isempty(labels)
               labels=this.getLabelPrefix;
           end
           if nargin<5 || isempty(labels2)
               labels2=this.getLabelPrefix;
           end
           %Reduce it:
           timeIdxs=find(this.Time<t1 & this.Time>=t0);
           [~,labelIdxs]=isaLabelPrefix(this,labels);
           [~,label2Idxs]=isaLabelPrefix(this,labels2);
           diffMatrix=diffMatrix(timeIdxs,labelIdxs,label2Idxs,:);
           Time=this.Time(timeIdxs);
           
        end
        
        function [distMatrix,labels,labels2,Time]=computeDistanceMatrix(this,t0,t1,labels,labels2)
           if nargin<2 || isempty(t0)
              t0=[]; 
           end
           if nargin<3 || isempty(t1)
               t1=[];
           end
           if nargin<4 || isempty(labels)
               labels=[];
           end
           if nargin<5 || isempty(labels2)
               labels2=[];
           end
            [diffMatrix,labels,labels2,Time]=computeDifferenceMatrix(this,t0,t1,labels,labels2);
            distMatrix=sqrt(sum(diffMatrix.^2,4));
        end

        %-------------------
        
        function labelPref=getLabelPrefix(this)
            aux=cellfun(@(x) x(1:end-1),this.labels,'UniformOutput',false);
            labelPref=aux(1:3:end);
        end
        
        function [boolFlag,labelIdx]=isaLabelPrefix(this,label)
             if isa(label,'char')
                auxLabel{1}=label;
            elseif isa(label,'cell')
                auxLabel=label;
            else
                error('labTimeSeries:isaLabel','label input argument has to be a string or a cell array containing strings.')
            end
            
            N=length(auxLabel);
            boolFlag=false(N,1);
            labelIdx=zeros(N,1);
            for j=1:N
                %Alternative efficient formulation:
                boolFlag(j)=any(strcmp(auxLabel{j},this.getLabelPrefix));
                labelIdx(j)=find(strcmp(auxLabel{j},this.getLabelPrefix));
            end
        end
        
        
        %-------------------
        %Modifier functions:
        
        function newThis=resampleN(this,newN) %Same as resample function, but directly fixing the number of samples instead of TS
            auxThis=this.resampleN@labTimeSeries(newN);
            newThis=orientedLabTimeSeries(auxThis.Data,auxThis.Time(1),auxThis.sampPeriod,auxThis.labels,this.orientation);
        end
        
        function newThis=split(this,t0,t1)
           auxThis=this.split@labTimeSeries(t0,t1);
           newThis=orientedLabTimeSeries(auxThis.Data,auxThis.Time(1),auxThis.sampPeriod,auxThis.labels,this.orientation);
        end
        
%         function newThis=derivate(this)
%             auxThis=this.derivate@labTimeSeries;
%             newThis.orientation=this.orientation;
%         end
        
    end
    methods (Static)
        function extendedLabels=addLabelSuffix(labels)
            	extendedLabels=cell(length(labels)*3);
                extendedLabels(1:3:end)=strcat(labels,'x');
                extendedLabels(2:3:end)=strcat(labels,'y');
                extendedLabels(3:3:end)=strcat(labels,'z');
        end 
        function labelSane=checkLabelSanity(labels)
            labelSane=true;
            %Check: labels is a multiple of 3
            if mod(length(labels),3)~=0
                warning('Label length is not a multiple of 3, therefore they can''t correspond to 3D oriented data.')
                labelSane=false;
                return
            end
            %Check: all labels end in 'x','y' or 'z'
            aux2=cellfun(@(x) x(end),labels,'UniformOutput',false); %Should be 'x', 'y', 'z'
            if any(~strcmp(aux2(1:3:end),'x')) || any(~strcmp(aux2(2:3:end),'y')) || any(~strcmp(aux2(3:3:end),'z'))
               warning('Labels do not end in ''x'', ''y'', or ''z'' or in that order, as expected.') 
               labelSane=false;
               return
            end
            %Check: and labels have the same prefix in groups of 3
            aux=cellfun(@(x) x(1:end-1),labels,'UniformOutput',false);
            labelsx=aux(1:3:end);
            labelsy=aux(2:3:end);
            labelsz=aux(3:3:end);
            if any(~strcmp(labelsx,labelsy)) || any(~strcmp(labelsx,labelsz))
                labelSane=false;
                return
            end
        end
    end

end

