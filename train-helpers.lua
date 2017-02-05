--[[
Copyright (c) 2016 Michael Wilber

This software is provided 'as-is', without any express or implied
warranty. In no event will the authors be held liable for any damages
arising from the use of this software.

Permission is granted to anyone to use this software for any purpose,
including commercial applications, and to alter it and redistribute it
freely, subject to the following restrictions:

1. The origin of this software must not be misrepresented; you must not
   claim that you wrote the original software. If you use this software
   in a product, an acknowledgement in the product documentation would be
   appreciated but is not required.
2. Altered source versions must be plainly marked as such, and must not be
   misrepresented as being the original software.
3. This notice may not be removed or altered from any source distribution.
--]]


require 'optim'
TrainingHelpers = {}


function evaluateModel(model, cnnModel, datasetTest, dataTrain, batchSize, trainCodes, learntCodeWords, neighboursMat, neighboursMatVis, neighboursMatImgnt)
   print("Evaluating...")
   model:evaluate()
   cnnModel:evaluate()
   local correct1 = 0
   local hadCorrect1 = 0
   local hadCorrect5 = 0
   local heirPrecision = 0
   local heirPrecisionVis = 0
   local heirPrecisionImgnt = 0
   local correct5 = 0
   local total = 0
   local mseLoss = 0
   local batches = torch.range(1, datasetTest:size()):long():split(batchSize)
   for i=1,#batches do
       collectgarbage(); collectgarbage();
       local results = datasetTest:sampleIndices(nil, batches[i])
       local batch, labels, augLabels, augLabelsFix = results.inputs, results.outputs, results.augLabels, results.augLabelsFix
       labels = labels:long()
       augLabels = augLabels:float()
       augLabels:renorm(2,1,1)
       augLabelsFix = augLabelsFix:float()

       eye = torch.eye(100)
       idx1 = 0
       local lebelsIndicVecs = torch.FloatTensor(labels:size(1), 100) 
       for i = 1,labels:size(1) do
              lebelsIndicVecs[i] = eye[labels[i]] 
	      if labels[i] == 1 then
	      	idx1 =  i
	      end
       end
--print(#lebelsIndicVecs:size())

       inputs = cnnModel:forward(batch:cuda())
       --local Y = model:forward({inputs, lebelsIndicVecs:cuda()})
       --local Y = model:forward(batch:cuda())

       total = total + labels:size(1) 
if trainCodes == 0 then

       local Y = model:forward(inputs:cuda())

       --y = Y[1]:float()
       y = Y:float()
       local _, indices = torch.sort(y, 2, true)
       -- indices has shape (batchSize, nClasses)
       local top1 = indices:select(2, 1)
       local top5 = indices:narrow(2, 1,5)
       top30 = indices:narrow(2, 1,30)
       hadCorrect1 = hadCorrect1 + torch.eq(top1, labels):sum()
       hadCorrect5 = hadCorrect5 + torch.eq(top5, labels:view(-1, 1):expandAs(top5)):sum()
       y1 = y
       --xlua.progress(total, datasetTest:size())

else
       local Y = model:forward({inputs, lebelsIndicVecs:cuda()})

       y1 = Y[1][1]:float()
       --y2 = augLabels:float():renorm(2,1,1)
       y2 = Y[2]:float()
       y4 = Y[1][2]:float() 	   
--[[		for j=1,y2:size(1) do
		learntCodeWords[labels[j]] --[[= y2[j]:float()
         	end --]]	   

if idx1 > 0 then
--       print(y1[idx1]:narrow(1,1,10))
end
       --codeWords = dataTrain:getCodeWords():float():renorm(2,1,1)
	   
	   codeWords = learntCodeWords--:renorm(2,1,1)
	   
--       codeWords[torch.lt(codeWords,1)] = -1
       top1 = labels:clone():zero() 
       top5 = torch.LongTensor(labels:size(1), 5):zero()
       top30 = torch.LongTensor(labels:size(1), 30):zero()

        --for j=1,y1:size(1) do
		-- find nearest codeword
			--a, ranks = torch.sort(torch.sum(torch.pow(codeWords-y1:narrow(1,j,1):repeatTensor(codeWords:size(1),1),2),2),1)

                local _, ranks = torch.sort(y4, 2, true)			
       		top1 = ranks:select(2,1)
	        top5 = ranks:narrow(2,1,5) --narrow(1,1,5)
                top30 = ranks:narrow(2,1,30) --narrow(1,1,30)
	--end

       hadCorrect1 = hadCorrect1 + torch.eq(top1, labels):sum()
       hadCorrect5 = hadCorrect5 + torch.eq(top5, labels:view(-1, 1):expandAs(top5)):sum()

       mse = nn.MSECriterion()
       mseLoss = mse:forward(y1, y2)
end

       neighbours = top30:clone():zero()
           for  j=1,y1:size(1) do
                neighbours[j] = neighboursMat[labels[j]]:narrow(1,1,30)
           end


       for j=1,y1:size(1) do
                for i = 1,30 do
--                      print(neighbours[j]:narrow(1,i,1))
                        heirPrecision =  heirPrecision + torch.eq(top30[j], neighbours[j][i]):sum()/30
                end
       end

       
      neighbours = top30:clone():zero()
           for  j=1,y1:size(1) do
                neighbours[j] = neighboursMatVis[labels[j]]:narrow(1,1,30)
           end


       for j=1,y1:size(1) do
                for i = 1,30 do
--                      print(neighbours[j]:narrow(1,i,1))
                        heirPrecisionVis =  heirPrecisionVis + torch.eq(top30[j], neighbours[j][i]):sum()/30
                end
       end

       neighbours = top30:clone():zero()
           for  j=1,y1:size(1) do
                neighbours[j] = neighboursMatImgnt[labels[j]]:narrow(1,1,30)
           end


       for j=1,y1:size(1) do
                for i = 1,30 do
--                      print(neighbours[j]:narrow(1,i,1))
                        heirPrecisionImgnt =  heirPrecisionImgnt + torch.eq(top30[j], neighbours[j][i]):sum()/30
                end
       end
   
end
   return {correct1=correct1/total, correct5=correct5/total, mse=mseLoss, hadCorrect1=hadCorrect1/total, hadCorrect5=hadCorrect5/total, heirPrecision=heirPrecision/total, heirPrecisionVis=heirPrecisionVis/total, heirPrecisionImgnt=heirPrecisionImgnt/total}
end

function TrainingHelpers.trainForever(forwardBackwardBatch, cnnWeights, cnnSgdState, epochSize, afterEpoch)
  
   print("original epoch size = ", epochSize)
   epochSize = epochSize/1
   print("new epoch size = ", epochSize)

 
   local d = Date{os.date()}
   local modelTag = string.format("%04d%02d%02d-%d",
      d:year(), d:month(), d:day(), torch.random())
   --local isInit = 1
   while true do -- Each epoch
      cnnSgdState.epochSize = epochSize
      cnnSgdState.epochCounter = cnnSgdState.epochCounter or 0
      cnnSgdState.nSampledImages = cnnSgdState.nSampledImages or 0
      cnnSgdState.nEvalCounter = cnnSgdState.nEvalCounter or 0
      local whichOptimMethod = optim.sgd
      if cnnSgdState.whichOptimMethod then
          whichOptimMethod = optim[cnnSgdState.whichOptimMethod]
      end

      collectgarbage(); collectgarbage()
      -- Run forward and backward pass on inputs and labels
--[[      local loss_val, loss_val2, weigths, sgdState, gradients, cnnGradients, batchProcessed = forwardBackwardBatch(0)

     -- print("learning rate = ", sgdState.learningRate)
      -- SGD step: modifies weights in-place
      whichOptimMethod(function() return loss_val+loss_val2, gradients end,
                       weights,
                       sgdState)
--]]
      local loss_val, loss_val2, weigths, sgdState, gradients, cnnGradients, batchProcessed = forwardBackwardBatch()

     -- print("learning rate = ", sgdState.learningRate)
      -- SGD step: modifies weights in-place
      whichOptimMethod(function() return loss_val+loss_val2, gradients end,
                       weights,
                       sgdState)

      whichOptimMethod(function() return loss_val+loss_val2, cnnGradients end,
                       cnnWeights,
                       cnnSgdState)

      -- Display progress and loss
      cnnSgdState.nSampledImages = cnnSgdState.nSampledImages + batchProcessed
      cnnSgdState.nEvalCounter = cnnSgdState.nEvalCounter + 1
      --xlua.progress(sgdState.nSampledImages%epochSize, epochSize)

      if math.floor(cnnSgdState.nSampledImages / epochSize) ~= cnnSgdState.epochCounter then
         -- Epoch completed!
         --xlua.progress(epochSize, epochSize)
         cnnSgdState.epochCounter = math.floor(cnnSgdState.nSampledImages / epochSize)
         if afterEpoch then afterEpoch() end
         print("\n\n----- Epoch "..cnnSgdState.epochCounter.." -----")
      end
   end
end


-- Some other stuff that may be helpful but I need to refactor it

-- function TrainingHelpers.inspectLayer(layer, fields)
--    function inspect(x)
--       if x then
--          x = x:double():view(-1)
--          return {
--             p5 = (x:kthvalue(1 + 0.05*x:size(1))[1]),
--             mean = x:mean(),
--             p95 = (x:kthvalue(1 + 0.95*x:size(1))[1]),
--             var = x:var(),
--          }
--       end
--    end
--    local result = {name = tostring(layer)}
--    for _,field in ipairs(fields) do
--       result[field] = inspect(layer[field])
--    end
--    return result
-- end
-- function TrainingHelpers.printLayerInspection(li, fields)
--    print("- "..tostring(li.name))
--    if (string.find(tostring(li.name), "ReLU")
--        or string.find(tostring(li.name), "BatchNorm")
--        or string.find(tostring(li.name), "View")
--        ) then
--        -- Do not print these layers
--    else
--        for _,field in ipairs(fields) do
--           local lf = li[field]
--           if lf then
--               print(string.format(
--                        "%20s    5p: %+3e    Mean: %+3e    95p: %+3e    Var: %+3e",
--                        field, lf.p5, lf.mean, lf.p95, lf.var))
--           end
--        end
--    end
-- end
-- function TrainingHelpers.inspectModel(model)
--    local results = {}
--    for i,layer in ipairs(model.modules) do
--       results[i] = TrainingHelpers.inspectLayer(layer, {"weight",
--                                                         "gradWeight",
--                                                         "bias",
--                                                         "gradBias",
--                                                         "output"})
--    end
--    return results
-- end
-- function TrainingHelpers.printInspection(inspection)
--    print("\n\n\n")
--    print(" \x1b[31m---------------------- Weights ---------------------- \x1b[0m")
--    for i,layer in ipairs(inspection) do
--       TrainingHelpers.printLayerInspection(layer, {"weight", "gradWeight"})
--    end
--    print(" \x1b[31m---------------------- Biases ---------------------- \x1b[0m")
--    for i,layer in ipairs(inspection) do
--       TrainingHelpers.printLayerInspection(layer, {"bias", "gradBias"})
--    end
--    print(" \x1b[31m---------------------- Outputs ---------------------- \x1b[0m")
--    for i,layer in ipairs(inspection) do
--       TrainingHelpers.printLayerInspection(layer, {"output"})
--    end
-- end
-- function displayWeights(model)
--     local layers = {}
--     -- Go through each module and add its weight and its gradient.
--     -- X axis = layer number.
--     -- Y axis = weight / gradient.
--     for i, li in ipairs(model.modules) do
--         if not (string.find(tostring(li), "ReLU")
--             or string.find(tostring(li), "BatchNorm")
--             or string.find(tostring(li), "View")
--             ) then
--             if li.gradWeight then
--                 --print(tostring(li),li.weight:mean())
--                 layers[#layers+1] = {i,
--                     -- Weight
--                     {li.weight:mean() - li.weight:std(),
--                     li.weight:mean(),
--                     li.weight:mean() + li.weight:std()},
--                     -- Gradient
--                     {li.gradWeight:mean() - li.gradWeight:std(),
--                     li.gradWeight:mean(),
--                     li.gradWeight:mean() + li.gradWeight:std()},
--                     -- Output
--                     {li.output:mean() - li.output:std(),
--                     li.output:mean(),
--                     li.output:mean() + li.output:std()},
--                 }
--             end
--         end
--     end
--     -- Plot the result
--     --
--    workbook:plot("Layers", layers, {
--                    labels={"Layer", "Weights", "Gradients", "Outputs"},
--                    customBars=true, errorBars=true,
--                    title='Network Weights',
--                    rollPeriod=1,
--                    win=26,
--                    --annotations={"o"},
--                    --axes={x={valueFormatter="function(x) {return x; }"}},
--              })
-- end
